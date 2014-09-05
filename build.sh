#!/bin/sh
set -e
export REQUIRE_GLOBAL="phpdocumentor/phpdocumentor:2.* pdepend/pdepend:1.1.1 phpmd/phpmd:1.5.0 squizlabs/php_codesniffer:1.4.7 sebastian/phpcpd:1.4.3 mayflower/php-codebrowser:1.1.0 phploc/phploc:2.0.2 sebastian/finder-facade:1.1.0 sebastian/version:1.0.1";
export REQUIRE="phpunit/phpunit:4.1.* imsamurai/cakephp-environment:0.*";
export PLUGIN_FULL_PATH=$WORKSPACE/../cakephp/app/$PLUGIN_PATH;
export GLOBAL_VENDOR=/home/snatz/.composer/vendor;

composer global require --dev --no-interaction --prefer-source --update-with-dependencies $REQUIRE_GLOBAL;

cd ${WORKSPACE}/

git clone https://github.com/FriendsOfCake/travis.git --depth 1 ../travis;
../travis/before_script.sh;

echo "<?php
		require_once '${GLOBAL_VENDOR}/autoload.php';
		require_once dirname(dirname(dirname(__FILE__))) . '/lib/Cake/Console/ShellDispatcher.php';
		return ShellDispatcher::run(\$argv);
	" > ../cakephp/app/Console/cake.php;

cat ../cakephp/app/Console/cake | sed 's/php -q/hhvm/' > ../cakephp/app/Console/cakehhvm;
chmod +x ../cakephp/app/Console/cake;
chmod +x ../cakephp/app/Console/cakehhvm;

rm -rf ../PHP/CodeSniffer/Standards/CakePHP;
git clone https://github.com/imsamurai/cakephp-codesniffer.git --depth 1 ../PHP/CodeSniffer/Standards/CakePHP;

mkdir -p build/api;
mkdir -p build/code-browser;
mkdir -p build/coverage;
mkdir -p build/logs;
mkdir -p build/pdepend;

chmod +x ../cakephp/app/Console/cake;

cp ../cakephp/app/phpunit.xml .;
echo "HHVM TESTS\n";
../cakephp/app/Console/cakehhvm --working ../cakephp/app test ${PLUGIN_NAME} All${PLUGIN_NAME};
echo "PHP TESTS\n";
../cakephp/app/Console/cake --working ../cakephp/app test ${PLUGIN_NAME} All${PLUGIN_NAME} --stderr --log-junit build/logs/junit.xml --coverage-clover build/logs/clover.xml --coverage-html build/coverage/;
echo "PHPLOC\n";
${GLOBAL_VENDOR}/bin/phploc --exclude Test --exclude TestSuite --exclude Plugin --log-csv build/logs/phploc.csv ${PLUGIN_FULL_PATH};
echo "PDEPEND\n";
${GLOBAL_VENDOR}/bin/pdepend --jdepend-xml=build/logs/jdepend.xml --jdepend-chart=build/pdepend/dependencies.svg --overview-pyramid=build/pdepend/overview-pyramid.svg --ignore=Test,Plugin,TestSuite ${PLUGIN_FULL_PATH};
echo "PHPMD\n";
${GLOBAL_VENDOR}/bin/phpmd --exclude Test,Plugin,TestSuite ${PLUGIN_FULL_PATH} text codesize,design,naming,unusedcode;
echo "PHPMD\n";
${GLOBAL_VENDOR}/bin/phpmd --exclude Test,Plugin,TestSuite ${PLUGIN_FULL_PATH} xml codesize,design,naming,unusedcode --reportfile build/logs/pmd.xml;
echo "PHPCS\n";
${GLOBAL_VENDOR}/bin/phpcs --report=checkstyle --report-file=build/logs/checkstyle.xml --standard=../PHP/CodeSniffer/Standards/CakePHP --encoding=utf-8 --extensions=php,ctp --ignore=test,Plugin,Vendor,Test,TestSuite ${PLUGIN_FULL_PATH};
echo "PHPCPD\n";
${GLOBAL_VENDOR}/bin/phpcpd --exclude Test --exclude TestSuite --exclude Plugin --exclude Vendor --log-pmd build/logs/pmd-cpd.xml ${PLUGIN_FULL_PATH};
echo "PHPDOC\n";
${GLOBAL_VENDOR}/bin/phpdoc --directory=${PLUGIN_FULL_PATH} --target=build/api --template=${GLOBAL_VENDOR}/phpdocumentor/templates/responsive-twig;
echo "PHPCB\n";
${GLOBAL_VENDOR}/bin/phpcb --log build/logs --source ${PLUGIN_FULL_PATH} --output build/code-browser -S 'php ctp';
exit 0;
