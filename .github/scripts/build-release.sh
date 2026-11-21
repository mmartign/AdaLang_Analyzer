#!/bin/sh
#  Builds and packages the release archive of AdaLang Analyzer for the host:
#  the executable, the CVC5 and Z3 solvers that --verify runs, the project's
#  documents, and the licenses of what the archive holds.
#
#  Usage: .github/scripts/build-release.sh <platform> <output-directory>
#    <platform>  the name the archive carries: linux-x86_64, macos-arm64,
#                windows-x86_64, ...
#  Run from the repository root, after "alr -n install gnatprove" (the
#  solvers are taken from it: SPARK_DIR, by default ~/.alire/libexec/spark).
#
#  The executable needs nothing outside the system: the GNAT run time is
#  linked in by the binder, GMP is linked in from its static library, and on
#  Windows the whole executable is static. The script stops if the result
#  depends on any other library, then runs the packaged executable with no
#  toolchain or solver on PATH.

set -eu

platform=$1
out=$2
spark=${SPARK_DIR:-$HOME/.alire/libexec/spark}
version=$(sed -n 's/^version = "\(.*\)"$/\1/p' alire.toml)
name=adalang_analyzer-$version-$platform
stage=$out/$name

case $(uname -s) in
   Linux) host=linux; exe= ;;
   Darwin) host=macos; exe= ;;
   MINGW* | MSYS* | CYGWIN*) host=windows; exe=.exe ;;
   *) echo "build-release: unknown host $(uname -s)" >&2; exit 1 ;;
esac

say() { printf '\n== %s\n' "$*"; }
fail() { echo "build-release: $*" >&2; exit 1; }

#  --- build -------------------------------------------------------------

#  A directory that holds only the static GMP library comes first in the
#  linker's search: the "-lgmp" of GNATCOLL's GMP binding then finds it
#  before the shared one beside it.
static=$out/static-libs
mkdir -p "$static"
case $host in
   linux)
      gmp=$(dpkg -L libgmp-dev | grep '/libgmp\.a$' | head -n 1)
      ;;
   macos)
      brew list --versions gmp >/dev/null || brew install gmp
      gmp=$(brew --prefix gmp)/lib/libgmp.a
      ;;
   windows)
      gmp=
      ;;
esac

say "build $version for $platform"
#  gprbuild does not link again for other linker options alone.
rm -f "bin/adalang_analyzer$exe"
case $host in
   windows)
      alr -n build
      ;;
   *)
      [ -f "$gmp" ] || fail "no static GMP library ($gmp)"
      ln -sf "$gmp" "$static/libgmp.a"
      extra=
      [ $host = linux ] && extra=-static-libgcc
      alr -n build -- -largs -L"$(cd "$static" && pwd)" $extra
      ;;
esac

analyzer=bin/adalang_analyzer$exe
[ -f "$analyzer" ] || fail "no $analyzer after the build"

#  --- stage -------------------------------------------------------------

say "stage $stage"
[ ! -e "$stage" ] || fail "$stage exists already"
mkdir -p "$stage/bin" "$stage/licenses"
cp "$analyzer" "$stage/bin/"
for solver in cvc5 z3; do
   [ -f "$spark/bin/$solver$exe" ] || fail "no $solver in $spark/bin"
   cp "$spark/bin/$solver$exe" "$stage/bin/"
done
cp README.md CHANGELOG.md LICENSE NOTICE "$stage/"

#  The solvers' licenses, as the GNATprove distribution ships them.
cp "$spark/COPYING" "$stage/licenses/cvc5-COPYING.txt"
cp "$spark/LICENSE.txt" "$stage/licenses/z3-LICENSE.txt"
for file in "$spark"/licenses/*; do
   cp "$file" "$stage/licenses/"
done

#  --- what the executable needs ----------------------------------------

say "libraries the packaged programs load"
case $host in
   linux)
      for program in "$stage"/bin/*; do
         echo "$program:"
         ldd "$program" | sed 's/^/   /'
         #  The analyzer needs only the C library's own parts and the
         #  dynamic loader; the solvers may also need the C++ library,
         #  which every distribution has.
         allowed='linux-vdso|ld-linux|lib(c|m|dl|rt|pthread|util)\.so'
         case $program in
            */adalang_analyzer) ;;
            *) allowed="$allowed|lib(stdc\\+\\+|gcc_s)\\.so" ;;
         esac
         if ldd "$program" | grep -v -E "$allowed" | grep -q '=>'; then
            fail "$program needs a library outside the C library"
         fi
      done
      glibc=$(objdump -T "$stage/bin/adalang_analyzer" |
              grep -o 'GLIBC_[0-9.]*' | sort -u -V | tail -n 1)
      echo "newest C library version the analyzer needs: $glibc"
      ;;
   macos)
      for program in "$stage"/bin/*; do
         echo "$program:"
         otool -L "$program" | tail -n +2 | sed 's/^/   /'
         if otool -L "$program" | tail -n +2 |
            grep -v -E '^[[:space:]]*/(usr/lib|System)/' | grep -q .
         then
            fail "$program needs a library outside the system"
         fi
      done
      ;;
   windows)
      for program in "$stage"/bin/*.exe; do
         echo "$program:"
         dlls=$(alr exec -- objdump -p "$program" |
                sed -n 's/^[[:space:]]*DLL Name: //p' | tr -d '\r')
         printf '   %s\n' $dlls
         for dll in $dlls; do
            #  A DLL of the solvers' own distribution goes beside them.
            if [ -f "$spark/bin/$dll" ] && [ ! -f "$stage/bin/$dll" ]; then
               cp "$spark/bin/$dll" "$stage/bin/"
               echo "   (copied $dll from $spark/bin)"
            fi
         done
      done
      if alr exec -- objdump -p "$stage/bin/adalang_analyzer.exe" |
         grep -i -E 'DLL Name: lib(gmp|iconv|gcc|winpthread|gnat|stdc)'
      then
         fail "the executable needs a DLL of MSYS2"
      fi
      ;;
esac

#  --- third-party notice -------------------------------------------------

say "third-party notice"
{
   echo "# Third-party components"
   echo
   echo "AdaLang Analyzer $version ($platform) is distributed under the GNU"
   echo "General Public License, version 3 or later: see LICENSE. The"
   echo "executable bin/adalang_analyzer$exe also contains the libraries"
   echo "below, linked in when it was built; the license of each is the"
   echo "one the Alire community index gives for that release."
   echo
   echo "| Component | Version | License |"
   echo "| --- | --- | --- |"
   alr -q show --solve | tr -d '\r' |
     sed -n '/^Dependencies (solution):/,/^Dependencies (graph):/p' |
     sed -n 's/^   \([a-z0-9_]*\)=\([^ ]*\).*/\1 \2/p' |
     while read -r crate release; do
        case $crate in
           make) continue ;;  # a build tool, not part of the executable
           gnat) crate=gnat_native ;;
           libgmp)
              echo "| GNU MP (libgmp, linked statically) | $release | LGPL-3.0-or-later OR GPL-2.0-or-later |"
              continue ;;
        esac
        license=$(alr -q show "$crate=$release" | tr -d '\r' |
                  sed -n 's/^ *License: //p' | paste -s -d ';' -)
        echo "| $crate | $release | ${license:-see the crate} |"
     done
   case $host in
      windows)
         echo "| GNU libiconv and mingw-w64 run-time libraries (MSYS2, linked statically) | as installed by Alire | LGPL-2.1-or-later; see each project |"
         ;;
   esac
   echo
   echo "bin/cvc5$exe and bin/z3$exe are the solvers of the GNATprove"
   echo "distribution that Alire installs (\`alr install gnatprove\`), as it"
   echo "ships them: \`--verify\` runs them. CVC5 is under the modified BSD"
   echo "license and is linked with LibPoly (LGPL-3.0-or-later), see"
   echo "licenses/cvc5-COPYING.txt and licenses/lgpl-3.0.txt; Z3 is under the"
   echo "MIT license, see licenses/z3-LICENSE.txt."
   echo
   echo "| Solver | Version |"
   echo "| --- | --- |"
   echo "| CVC5 | $("$stage/bin/cvc5$exe" --version | head -n 1 | tr -d '\r') |"
   echo "| Z3 | $("$stage/bin/z3$exe" --version | tr -d '\r') |"
   echo
   echo "The source of this release is its tag, v$version, at"
   echo "https://github.com/mmartign/AdaLang_Analyzer; the source of each"
   echo "component above, at the version given, is in the Alire community"
   echo "index (\`alr get <crate>=<version>\`)."
} >"$stage/THIRD-PARTY.md"
cat "$stage/THIRD-PARTY.md"

#  --- smoke test -----------------------------------------------------------

#  From outside the repository, with neither a toolchain nor a solver on
#  PATH and no home directory to find Alire's: the solvers that run are
#  those beside the executable.
say "smoke test"
fixture=$(pwd)/tests/verification_vc_contracts.adb
report=$out/smoke.json
case $host in
   windows)
      #  A Windows program is given Windows paths, and no profile directory
      #  in which to find the solvers "alr install gnatprove" put there.
      (cd "$out" &&
       PATH=/usr/bin HOME=/nonexistent USERPROFILE='C:\nonexistent' \
         "$name/bin/adalang_analyzer.exe" --version &&
       PATH=/usr/bin HOME=/nonexistent USERPROFILE='C:\nonexistent' \
         "$name/bin/adalang_analyzer.exe" --no-config --verify --format=json \
         --output="$(cygpath -w "$report")" "$(cygpath -w "$fixture")") ||
        true
      ;;
   *)
      (cd "$out" && env -i PATH=/usr/bin:/bin HOME=/nonexistent \
         "$name/bin/adalang_analyzer" --version)
      (cd "$out" && env -i PATH=/usr/bin:/bin HOME=/nonexistent \
         "$name/bin/adalang_analyzer" --no-config --verify --format=json \
         --output="$report" "$fixture") || true
      ;;
esac
[ -f "$report" ] || fail "the packaged analyzer wrote no report"
runs=$(python3 -c 'import json, sys
print(json.load(open(sys.argv[1]))["solverStatistics"]["runs"])' "$report" ||
       python -c 'import json, sys
print(json.load(open(sys.argv[1]))["solverStatistics"]["runs"])' "$report")
echo "solver runs in the smoke test: $runs"
[ "$runs" -gt 0 ] || fail "the packaged analyzer ran no solver"
rm -f "$report"

#  --- archive ---------------------------------------------------------------

say "archive"
case $host in
   windows)
      archive=$name.zip
      (cd "$out" && 7z a -tzip -bd "$archive" "$name" >/dev/null)
      ;;
   *)
      archive=$name.tar.gz
      (cd "$out" && tar -czf "$archive" "$name")
      ;;
esac
(cd "$out" &&
 if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$archive"
 else
    shasum -a 256 "$archive"
 fi >"$archive.sha256")
cat "$out/$archive.sha256"
ls -l "$out/$archive"
