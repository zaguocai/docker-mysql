#!/usr/bin/env bash
set -e
set -u
set -o pipefail

IMAGE="zaguocai/mysql"
#NAME="${1}"
#VERSION="${2}"
TAG="${3}"
ARCH="${4}"
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

CWD="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck disable=SC1091
. "${CWD}/.lib.sh"


# Start MySQL
echo "1/5 Starting MySQL"
run "docker run -d --rm --platform ${ARCH} $(tty -s && echo "-it" || echo) --hostname=mysql --name bypanel-test-mysql -e MYSQL_ALLOW_EMPTY_PASSWORD=yes ${IMAGE}:${TAG}"

# Pull PHP image
echo "2/5 Pulling PHP image "
while ! run "docker pull --platform ${ARCH} php:7.2"; do
	sleep 1
done

# Start PHP 7.2
echo "3/5 Starting PHP"
run "docker run -d --rm --platform ${ARCH} $(tty -s && echo "-it" || echo) --hostname=php --name bypanel-test-php -v ${SCRIPTPATH}:/tmp --link bypanel-test-mysql php:7.2 sh -c 'sleep 9000'"

# Install PHP mysqli module
echo "4/5 Installing mysqli extension"
if ! run "docker exec $(tty -s && echo "-it" || echo) bypanel-test-php sh -c 'docker-php-ext-install mysqli'"; then
	docker logs bypanel-test-php    2>/dev/null || true
	docker logs bypanel-test-mysql  2>/dev/null || true
	docker stop bypanel-test-php    2>/dev/null || true
	docker stop bypanel-test-mysql  2>/dev/null || true
	docker kill bypanel-test-php    2>/dev/null || true
	docker kill bypanel-test-mysql  2>/dev/null || true
	docker rm -f bypanel-test-php   2>/dev/null || true
	docker rm -f bypanel-test-mysql 2>/dev/null || true
	exit 1
fi

# Test MySQL connectivity
max=100
i=0
echo "5/5 Testing mysqli extension"
while ! run "docker exec $(tty -s && echo "-it" || echo) bypanel-test-php php /tmp/mysql.php >/dev/null 2>&1"; do
	printf "."
	sleep 1
	i=$(( i + 1))
	if [ "${i}" -ge "${max}" ]; then
		printf "\\n"
		>&2 echo "Failed"
		docker exec "$(tty -s && echo "-it" || echo)" bypanel-test-php php /tmp/mysql.php || true
		docker logs bypanel-test-php    2>/dev/null || true
		docker logs bypanel-test-mysql  2>/dev/null || true
		docker stop bypanel-test-php    2>/dev/null || true
		docker stop bypanel-test-mysql  2>/dev/null || true
		docker kill bypanel-test-php    2>/dev/null || true
		docker kill bypanel-test-mysql  2>/dev/null || true
		docker rm -f bypanel-test-php   2>/dev/null || true
		docker rm -f bypanel-test-mysql 2>/dev/null || true
		exit 1
	fi
done
printf "\\n"

run "docker stop bypanel-test-php"    || true
run "docker stop bypanel-test-mysql"  || true
run "docker kill bypanel-test-php"    || true
run "docker kill bypanel-test-mysql"  || true
run "docker rm -f bypanel-test-php"   || true
run "docker rm -f bypanel-test-mysql" || true
echo "Success"
