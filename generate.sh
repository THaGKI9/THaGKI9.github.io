#!/bin/sh

echo "version: 2.3.0" >> ./themes/icarus/_config.yml
cp ./themes/patches/icarus-profile.ejs ./themes/icarus/layout/widget/profile.ejs
npm run hexo generate
