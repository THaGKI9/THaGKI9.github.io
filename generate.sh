#!/bin/sh

echo "version: 2.3.0" > ./themes/icarus/_config.yml
cp ./themes/patches/icarus-profile.ejs ./themes/icarus/layout/widget/profile.ejs
cp ./themes/patches/icarus-navbar.ejs ./themes/icarus/layout/common/navbar.ejs
cp ./themes/patches/icarus-footer.ejs ./themes/icarus/layout/common/footer.ejs
cp ./themes/patches/icarus-head.ejs ./themes/icarus/layout/common/head.ejs
npm run hexo generate
