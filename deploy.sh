#!/bin/sh
rm -rf public
git clone -b master "https://thagki9:${GITHUB_TOKEN}@github.com/THaGKI9/THaGKI9.github.io.git" public
cd public
git rm -rf *
cd ..

./generate.sh
cd public
git add .

git commit -m "Update site on $(date -u)"
git push origin master
