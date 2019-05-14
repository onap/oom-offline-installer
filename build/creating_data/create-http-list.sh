#! /usr/bin/env bash
###############################################################################
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
###############################################################################
# This script generates list of urls of the files that are needed to build offline given maven artefact.
# It expects path to pom.xml file (mandatory), path to temporary_repo (default: /tmp/mvn_temp_repo),
# path to output file, maven settings.xml location, clean temporary repo flag (default: false)
###############################################################################

function help() {
    echo "
    Example usage: create-http-list.sh -f <path/to/pom.xml> -t <path/to/temp_repo> -o <path/to/output> -s <path/to/settings.xml> -c

     -f | --file input file to be processed (mandatory)
     -o | --output output file containing url list of dependencies to be downloaded (default: ./http_list)
     -s | --settings  mvn setting.xml file containing list of repositories expected to host artefact dependencies (default ~/.m2/settings.xml)
     -t | --temp_repo temporary mvn local repository (default /tmp/temp_repo)
     -c | --clean flag, if set: output and temp_repo will be cleaned before dependencies collecting (default false)

     NOTE: If processing multiple pom.xml files in a row, to obtain aggregated dependencies for all of them clean flag should NOT be used.
    "
}
###########################################
#                 MAIN                    #
###########################################
clean=0
temp_repo="/tmp/temp_repo"
output="./http_list"
settings="~/.m2/settings.xml"

while [ "$1" != "" ]; do
    case $1 in
        -f | --file )           shift
                                file=$1
                                ;;
        -t | --temp_repo )      shift
                                temp_repo=$1
                                ;;
        -o | --output )         shift
                                output=$1
                                ;;
        -s | --settings )       shift
                                settings=$1
                                ;;
        -c | --clean )          clean=1
                                ;;
        -h | --help )           help
                                exit
                                ;;
        * )                     help
                                exit 1
    esac
    shift
done


mkdir -p ${temp_repo}
RC=$?
if [ ${RC} -ne "0" ]; then echo "Failed to create temporary repository folder, please check input parameters "; help; exit 1; fi

touch ${output}
RC=$?
if [ ${RC} -ne "0" ]; then echo "Failed to create output file, please check input parameters"; help; exit 1; fi

if [ ${clean} -eq "1" ]
  then
    rm -rf ${temp_repo}/*
    > ${output}
fi


echo "Generating http list ${output} of maven dependencies based on ${file}"
mvn --settings ${settings} clean package -Dmaven.test.skip=true -Dmaven.repo.local=${temp_repo} --f ${file} > tmp_file
RC=$?
if [ ${RC} -ne "0" ]; then echo "Failed to package artefact,  pom.xml could be faulty"; help; exit 1; fi
echo "Maven build was successful"
cat tmp_file  | grep Downloading | grep -o "http.*" >> ${output}
RC=$?
if [ ${RC} -ne "0" ]; then echo "No new packages were downloaed"; exit 0; fi
sort -u ${output} > tmp_file && mv -f tmp_file ${output}
echo "New entries have been added to ${output}"

