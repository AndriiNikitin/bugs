docker build . --tag=mdev-13769
cat test.sh | docker run -i --rm mdev-13769
