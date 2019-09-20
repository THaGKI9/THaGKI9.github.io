#!/bin/sh

echo "version: 2.6.0" > ./themes/icarus/_config.yml
cp ./themes/patches/icarus-navbar.ejs ./themes/icarus/layout/common/navbar.ejs
cp ./themes/patches/icarus-footer.ejs ./themes/icarus/layout/common/footer.ejs
cp ./themes/patches/icarus-plugin-clipboard.ejs ./themes/icarus/layout/plugin/clipboard.ejs
npm run hexo generate
