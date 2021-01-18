set -xe
[ $# -eq 1 ] || (echo please specify a version ; exit 1)
crystal build --release umberbar.cr
cp umberbar umberbar-linux-x86-64
hub release create -a umberbar-linux-x86-64 -m $1 $1
