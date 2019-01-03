#   COPYRIGHT NOTICE STARTS HERE
#
#   Copyright 2018 © Samsung Electronics Co., Ltd.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
#   COPYRIGHT NOTICE ENDS HERE


if [[ -z "$ONAP_SERVERS" ]]; then
#    ONAP_SERVERS="oom-beijing-postRC2-master oom-beijing-postRC2-compute1 oom-beijing-postRC2-compute2"
    echo "Missing environment ONAP_SERVERS"
    exit 1
fi
if [[ -z "$LISTS_DIR" ]]; then
    LISTS_DIR=.
    echo "Using default output directory ."
fi

echo "Using onap servers: $ONAP_SERVERS"

cd $(dirname $0)

for server in $ONAP_SERVERS; do

    echo "================================================="
    echo "Gathering docker images list from server: $server"
    echo "================================================="
    scp ./make-docker-images-list.sh $server:/tmp/
    ssh $server '/tmp/make-docker-images-list.sh;rm /tmp/make-docker-images-list.sh'
    scp $server:/tmp/docker_image_list.txt $LISTS_DIR/docker_image_list-${server}.txt

    echo "================================================="
    echo "Gathering NPM packages list from server: $server"
    echo "================================================="
    scp ./make-npm-list.sh $server:/tmp/
    ssh $server '/tmp/make-npm-list.sh; rm /tmp/make-npm-list.sh'
    scp $server:/tmp/npm.list $LISTS_DIR/npm_list-${server}.txt
done

cat "$LISTS_DIR"/docker_image_list-*.txt | grep -v sonatype/nexus3 | grep -v own_nginx | sort | uniq > "$LISTS_DIR/docker_image_list.txt"
cat "$LISTS_DIR"/npm_list-*.txt | grep -v '^@$' | sort | uniq > "$LISTS_DIR/npm_list.txt"

