#! /usr/bin/env bash

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


# fail fast
set -e

# boilerplate
RELATIVE_PATH=./ # relative path from this script to 'common-functions.sh'
if [ "$IS_COMMON_FUNCTIONS_SOURCED" != YES ] ; then
    SCRIPT_DIR=$(dirname "${0}")
    LOCAL_PATH=$(readlink -f "$SCRIPT_DIR")
    . "${LOCAL_PATH}"/"${RELATIVE_PATH}"/common-functions.sh
fi

if [ -z "$1" ]; then
  VERSION="RC3"
  message info "no argument supplied, keeping default naming: $VERSION"
else
  VERSION="$1"
fi

# name of the self-extract-installer
TARGET_FILE="$APROJECT_DIR/selfinstall_onap_beijing_"$VERSION".sh"

# inserting the head of the script
cat > "$TARGET_FILE" <<EOF
#! /usr/bin/env bash

#
# This is self-extract installer for onap
#

# fail fast
set -e

# boilerplate
SCRIPT_DIR=\$(dirname "\${0}")
APROJECT_DIR=\$(readlink -f "\$SCRIPT_DIR")
IS_SELF_EXTRACT=YES

EOF

# splicing the scripts together
cat "${LOCAL_PATH}"/"${RELATIVE_PATH}"/common-functions.sh >> "$TARGET_FILE"
cat "${LOCAL_PATH}"/"${RELATIVE_PATH}"/deploy_nexus.sh >> "$TARGET_FILE"
cat "${LOCAL_PATH}"/"${RELATIVE_PATH}"/deploy_kube.sh >> "$TARGET_FILE"

# finishing touches to the script
cat >> "$TARGET_FILE" <<EOF

exit 0

#
# Installer script ends here
# The rest of this file is a binary payload
# ! DO NOT MODIFY IT !
#

# PAYLOAD BELOW #
EOF

# appending the tar to the script
cd "$APROJECT_DIR"
tar -h --exclude='.git' --exclude='*.swp' --exclude='selfinstall_onap_*.sh' --exclude='ansible' --exclude='docker' --exclude='local_repo.conf' --exclude='live' -cvf - * >> "$TARGET_FILE"
cd -

chmod 755 "$TARGET_FILE"
message info "Created Nexus self installation file: $TARGET_FILE"

exit 0
