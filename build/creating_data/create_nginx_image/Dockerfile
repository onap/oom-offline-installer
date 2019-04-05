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

FROM nginx:alpine

RUN apk add --no-cache --update fcgiwrap git git-daemon spawn-fcgi

ADD VERSION .

COPY gitconfig /etc/

CMD spawn-fcgi -M 666 -s /var/run/fcgiwrap.socket /usr/bin/fcgiwrap && \
    nginx -g "daemon off;"

