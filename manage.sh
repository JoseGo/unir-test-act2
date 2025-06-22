#!/bin/bash
set -e
 
ZAP_API_KEY="my_zap_api_key"
ZAP_API_URL="http://zap-node:8080/"
ZAP_TARGET_URL="http://calc-web/"
JMETER_RESULTS_FILE="results/jmeter_results.csv"
JMETER_REPORT_FOLDER="results/jmeter/"
 
COMMAND=$1
 
function show_help() {
    echo "Uso: ./manage.sh <comando>"
    echo "Comandos disponibles:"
    grep -E '^function [a-zA-Z0-9_-]+\(\)' "$0" | sed 's/function \(.*\)()/  \1/' | sort
}
 
function build() {
    docker build -t calculator-app .
    docker build -t calc-web ./web
}
 
function run() {
    docker run --rm -v "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest python -B app/calc.py
}
 
function server() {
    docker run --rm --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
}
 
function interactive() {
    docker run -ti --rm -v "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest bash
}
 
function test-unit() {
    docker run --name unit-tests --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pytest --cov --cov-report=xml:results/coverage.xml --cov-report=html:results/coverage --junit-xml=results/unit_result.xml -m unit || true
    docker cp unit-tests:/opt/calc/results ./ || true
    docker rm unit-tests || true
    docker run --rm -v "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/unit_result.xml results/unit_result.html
}
 
function test-api() {
    docker network create calc-test-api || true
    docker run -d --rm --volume "$PWD":/opt/calc --network calc-test-api --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
    docker run --rm --volume "$PWD":/opt/calc --network calc-test-api --env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserver:5000/ -w /opt/calc calculator-app:latest pytest --junit-xml=results/api_result.xml -m api || true
    docker run --rm --volume "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/api_result.xml results/api_result.html
    docker stop apiserver || true
    docker rm --force apiserver || true
    docker network rm calc-test-api
}
 
function test-e2e() {
    docker network create calc-test-e2e || true
    docker stop apiserver || true && docker rm --force apiserver || true
    docker stop calc-web || true && docker rm --force calc-web || true
    docker run -d --rm --volume "$PWD":/opt/calc --network calc-test-e2e --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
    docker run -d --rm --volume "$PWD"/web:/usr/share/nginx/html --volume "$PWD"/web/constants.test.js:/usr/share/nginx/html/constants.js --volume "$PWD"/web/nginx.conf:/etc/nginx/conf.d/default.conf --network calc-test-e2e --name calc-web -p 80:80 nginx
    docker run --rm --volume "$PWD"/test/e2e/cypress.json:/cypress.json --volume "$PWD"/test/e2e/cypress:/cypress --volume "$PWD"/results:/results --network calc-test-e2e cypress/included:4.9.0 --browser chrome || true
    docker rm --force apiserver calc-web || true
    docker run --rm --volume "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/cypress_result.xml results/cypress_result.html
    docker network rm calc-test-e2e
}
 
function run-web() {
    docker run --rm --volume "$PWD"/web:/usr/share/nginx/html --volume "$PWD"/web/constants.local.js:/usr/share/nginx/html/constants.js --volume "$PWD"/web/nginx.conf:/etc/nginx/conf.d/default.conf --name calc-web -p 80:80 nginx
}
 
function stop-web() {
    docker stop calc-web || true
}
 
function start-sonar-server() {
    docker network create calc-sonar || true
    docker run -d --rm --stop-timeout 60 --network calc-sonar --name sonarqube-server -p 9000:9000 -v "$PWD"/sonar/data:/opt/sonarqube/data -v "$PWD"/sonar/logs:/opt/sonarqube/logs sonarqube:8.3.1-community
}
 
function stop-sonar-server() {
    docker stop sonarqube-server || true
    docker network rm calc-sonar || true
}
 
function start-sonar-scanner() {
    docker run --rm --network calc-sonar -v "$PWD":/usr/src sonarsource/sonar-scanner-cli
}
 
function pylint() {
    docker run --rm --volume "$PWD":/opt/calc --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pylint app/ | tee results/pylint_result.txt
}
 
function deploy-stage() {
    docker stop apiserver calc-web || true
    docker run -d --rm --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5000:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
    docker run -d --rm --name calc-web -p 80:80 calc-web
}
 
# Ejecutar el comando
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi
 
if declare -f "$COMMAND" > /dev/null; then
    shift
    "$COMMAND" "$@"
else
    echo "Comando no reconocido: $COMMAND"
    show_help
    exit 1
fi