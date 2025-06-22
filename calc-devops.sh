#!/bin/bash

set -e

# Configuraciones
ZAP_API_KEY="my_zap_api_key"
ZAP_API_URL="http://zap-node:8080/"
ZAP_TARGET_URL="http://calc-web/"
JMETER_RESULTS_FILE="results/jmeter_results.csv"
JMETER_REPORT_FOLDER="results/jmeter/"

show_help() {
    echo "Uso: $0 <comando>"
    echo "Comandos disponibles:"
    grep -E '^function [a-zA-Z0-9_-]+\(\)' "$0" | sed 's/function \(.*\)()/  \1/'
}

function build() {
    docker build -t calculator-app .
}

function run() {
    docker run --rm -v "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest python -B app/calc.py
}

function server() {
    docker run --rm -v "$PWD":/opt/calc --name apiserver --network calc-net --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
}

function interactive() {
    docker run -ti --rm -v "$PWD":/opt/calc --env PYTHONPATH=/opt/calc  -w /opt/calc calculator-app:latest bash
}

function test-unit() {
    docker run --rm -v "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pytest --cov --cov-report=xml:results/coverage.xml --cov-report=html:results/coverage --junit-xml=results/unit_result.xml -m unit || true
    docker run --rm -v "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/unit_result.xml results/unit_result.html
}

function test-behavior() {
   docker run --rm --volume "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest behave --junit --junit-directory results/  --tags ~@wip test/behavior/
   docker run --rm --volume "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest bash test/behavior/junit-reports.sh
}

function test-api() {
    docker network create calc-test-api || true
	docker run -d --rm --volume "$PWD":/opt/calc --network calc-test-api --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run --rm --volume "$PWD":/opt/calc --network calc-test-api --env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserver:5000/ -w /opt/calc calculator-app:latest pytest --junit-xml=results/api_result.xml -m api  || true
	docker run --rm --volume "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/api_result.xml results/api_result.html
	docker stop apiserver || true
	docker rm --force apiserver || true
	docker network rm calc-test-api
}

function test-e2e() {
    docker network create calc-test-e2e || true
	docker stop apiserver || true
	docker rm --force apiserver || true
	docker stop calc-web || true
	docker rm --force calc-web || true
	docker run -d --rm --volume `pwd`:/opt/calc --network calc-test-e2e --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run -d --rm --volume `pwd`/web:/usr/share/nginx/html --volume `pwd`/web/constants.test.js:/usr/share/nginx/html/constants.js --volume `pwd`/web/nginx.conf:/etc/nginx/conf.d/default.conf --network calc-test-e2e --name calc-web -p 80:80 nginx
	docker run --rm --volume `pwd`/test/e2e/cypress.json:/cypress.json --volume `pwd`/test/e2e/cypress:/cypress --volume `pwd`/results:/results  --network calc-test-e2e cypress/included:4.9.0 --browser chrome || true
	docker rm --force apiserver
	docker rm --force calc-web
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/cypress_result.xml results/cypress_result.html
	docker network rm calc-test-e2e
}

function test-e2e-wiremock() {
    docker network create calc-test-e2e-wiremock || true
	docker stop apiwiremock || true
	docker rm --force apiwiremock || true
	docker stop calc-web || true
	docker rm --force calc-web || true
	docker run -d --rm --name apiwiremock --volume `pwd`/test/wiremock/stubs:/home/wiremock --network calc-test-e2e-wiremock -p 8080:8080 -p 8443:8443 calculator-wiremock
	docker run -d --rm --volume `pwd`/web:/usr/share/nginx/html --volume `pwd`/web/constants.wiremock.js:/usr/share/nginx/html/constants.js --volume `pwd`/web/nginx.conf:/etc/nginx/conf.d/default.conf --network calc-test-e2e-wiremock --name calc-web -p 80:80 nginx
	docker run --rm --volume `pwd`/test/e2e/cypress.json:/cypress.json --volume `pwd`/test/e2e/cypress:/cypress --volume `pwd`/results:/results --network calc-test-e2e-wiremock cypress/included:4.9.0 --browser chrome || true
	docker rm --force apiwiremock
	docker rm --force calc-web
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/cypress_result.xml results/cypress_result.html
	docker network rm calc-test-e2e-wiremock
}

function run-web() {
    docker run --rm --volume `pwd`/web:/usr/share/nginx/html  --volume `pwd`/web/constants.local.js:/usr/share/nginx/html/constants.js --volume `pwd`/web/nginx.conf:/etc/nginx/conf.d/default.conf --name calc-web -p 80:80 nginx
}

function stop-web() {
    docker stop calc-web
}

function start-sonar-server() {
    docker network create calc-sonar || true
	docker run -d --rm --stop-timeout 60 --network calc-sonar --name sonarqube-server -p 9000:9000 --volume `pwd`/sonar/data:/opt/sonarqube/data --volume `pwd`/sonar/logs:/opt/sonarqube/logs sonarqube:8.3.1-community
}

function start-sonar-scanner() {
    docker run --rm --network calc-sonar -v `pwd`:/usr/src sonarsource/sonar-scanner-cli
}

function pylint() {
    docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pylint app/ | tee results/pylint_result.txt    
}

function build-wiremock() {
    docker build -t calculator-wiremock -f test/wiremock/Dockerfile test/wiremock/
}

function start-wiremock() {
    docker run -d --rm --name calculator-wiremock --volume `pwd`/test/wiremock/stubs:/home/wiremock -p 8080:8080 -p 8443:8443 calculator-wiremock
}

function stop-wiremock() {
    docker stop calculator-wiremock || true
}

function zap-scan() {
    docker network create calc-test-zap || true
	docker run -d --rm --network calc-test-zap --volume `pwd`:/opt/calc --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run -d --rm --network calc-test-zap --volume `pwd`/web:/usr/share/nginx/html  --volume `pwd`/web/constants.test.js:/usr/share/nginx/html/constants.js --volume `pwd`/web/nginx.conf:/etc/nginx/conf.d/default.conf --name calc-web -p 80:80 nginx
	docker run -d --rm --network calc-test-zap --name zap-node -u zap -p 8080:8080 -i owasp/zap2docker-stable zap.sh -daemon -host 0.0.0.0 -port 8080 -config api.addrs.addr.name=.* -config api.addrs.addr.regex=true -config api.key=$(ZAP_API_KEY)
	sleep 10
	docker run --rm --volume `pwd`:/opt/calc --network calc-test-zap --env PYTHONPATH=/opt/calc --env ZAP_API_KEY=$(ZAP_API_KEY) --env ZAP_API_URL=$(ZAP_API_URL) --env TARGET_URL=$(ZAP_TARGET_URL) -w /opt/calc calculator-app:latest pytest --junit-xml=results/sec_result.xml -m security  || true
	docker run --rm --volume `pwd`:/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/sec_result.xml results/sec_result.html
	docker stop apiserver || true
	docker stop calc-web || true
	docker stop zap-node || true
	docker network rm calc-test-zap || true
}

function build-jmeter() {
    docker build -t calculator-jmeter -f test/jmeter/Dockerfile test/jmeter
}

function start-jmeter-record() {
    docker network create calc-test-jmeter || true
	docker run -d --rm --network calc-test-jmeter --volume `pwd`:/opt/calc --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run -d --rm --network calc-test-jmeter --volume `pwd`/web:/usr/share/nginx/html  --volume `pwd`/web/constants.test.js:/usr/share/nginx/html/constants.js --volume `pwd`/web/nginx.conf:/etc/nginx/conf.d/default.conf --name calc-web -p 80:80 nginx
}

function stop-jmeter-record() {
    docker stop apiserver || true
	docker stop calc-web || true
	docker network rm calc-test-jmeter || true
}

# Ejecutar la función indicada como argumento
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

"$@"
