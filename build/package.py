#! /usr/bin/env python3
# -*- coding: utf-8 -*-

#   COPYRIGHT NOTICE STARTS HERE

#   Copyright 2019 . Samsung Electronics Co., Ltd.
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

#   COPYRIGHT NOTICE ENDS HERE

from datetime import datetime
import subprocess
import argparse
import logging
import shutil
import glob
import json
import sys
import os
import hashlib

import tarfile
import git

log = logging.getLogger(__name__)
script_location = os.path.abspath(os.path.join(__file__, '..'))
offline_repository_dir = os.path.abspath(os.path.join(script_location, '..'))


def prepare_application_repository(directory, url, refspec, patch_path):
    """
    Downloads git repository according to refspec, applies patch if provided
    :param directory: path to repository
    :param url: url to repository
    :param refspec: refspec to fetch
    :param patch_path: path git patch to be applied over repository
    :return: repository - git repository object
    """

    try:
        shutil.rmtree(directory)
    except FileNotFoundError:
        pass

    log.info('Cloning {} with refspec {} '.format(url, refspec))
    repository = git.Repo.init(directory)
    origin = repository.create_remote('origin', url)
    origin.pull(refspec)
    repository.git.submodule('update', '--init')

    if patch_path:
        log.info('Applying {} over {} {}'.format(patch_path,
                                                 url,
                                                 refspec))
        repository.git.apply(patch_path)
    else:
        log.info('No patch file provided, skipping patching')

    return repository


def create_package_info_file(output_file, repository_list, tag, metadata):
    """
    Generates text file in json format containing basic information about the build
    :param output_file:
    :param repository_list: list of repositories to be included in package info
    :param tag: build version of packages
    :param metadata: additional metadata into package.info
    :return:
    """
    log.info('Generating package.info file')
    build_info = {
        'Build_info': {
            'build_date': datetime.now().strftime('%Y-%m-%d_%H-%M'),
            'Version': tag,
            'Packages': {}
        }
    }
    for repository in repository_list:
        build_info['Build_info'][
            repository.config_reader().get_value('remote "origin"', 'url')] = repository.head.commit.hexsha

    if metadata:
        for meta in metadata:
            build_info['Build_info'].update(meta)

    with open(output_file, 'w') as outfile:
        json.dump(build_info, outfile, indent=4)


def add_checksum_info(output_dir):
    """
    Add checksum information into package.info file
    :param output_dir: directory where are packages
    """
    tar_files = ['resources_package.tar', 'aux_package.tar', 'sw_package.tar']
    for tar_file in tar_files:
        try:
            data = os.path.join(output_dir, tar_file)
            cksum = hashlib.md5(open(data, 'rb').read()).hexdigest()
            with open(os.path.join(output_dir, 'package.info'), 'r') as f:
                json_data = json.load(f)
                json_data['Build_info']['Packages'].update({tar_file: cksum})
            with open(os.path.join(output_dir, 'package.info'), 'w') as f:
                json.dump(json_data, f, indent=4)
        except FileNotFoundError:
            pass


def create_package(tar_content, file_name):
    """
    Creates packages
    :param tar_content: list of dictionaries defining src file and destination tar file
    :param file_name: output file
    """
    log.info('Creating package {}'.format(file_name))
    with tarfile.open(file_name, 'w') as output_tar_file:
        for src, dst in tar_content.items():
            if src != '':
                output_tar_file.add(src, dst)


def metadata_validation(param):
    """
    Validation of metadata parameters
    :param param: parameter to be checked needs to be in format key=value
    """
    try:
        key, value = param.split('=')
        if not value:
            raise ValueError
        return {key: value}
    except ValueError:
        msg = "%r is not a valid parameter. Needs to be in format key=value" % param
        raise argparse.ArgumentTypeError(msg)


def build_offline_deliverables(build_version,
                               application_repository_url,
                               application_repository_reference,
                               application_patch_file,
                               application_charts_dir,
                               application_configuration,
                               application_patch_role,
                               output_dir,
                               resources_directory,
                               aux_directory,
                               skip_sw,
                               skip_resources,
                               skip_aux,
                               overwrite,
                               metadata):
    """
    Prepares offline deliverables
    :param build_version: Version for packages tagging
    :param application_repository_url: git repository hosting application helm charts
    :param application_repository_reference: git refspec for repository hosting application helm charts
    :param application_patch_file: git patch file to be applied over application repository
    :param application_charts_dir: path to directory under application repository containing helm charts
    :param application_configuration:  path to application configuration file (helm override configuration)
    :param application_patch_role: path to application patch role (executed just before helm deploy)
    :param output_dir: Destination directory for saving packages
    :param resources_directory: Path to resource directory
    :param aux_directory: Path to aux binary directory
    :param skip_sw: skip sw package generation
    :param skip_resources: skip resources package generation
    :param skip_aux: skip aux package generation
    :param overwrite: overwrite files in output directory
    :param metadata: add metadata info into package.info
    :return:
    """

    if os.path.exists(output_dir) and os.listdir(output_dir):
        if not overwrite:
            log.error('Output directory is not empty, use overwrite to force build')
            raise FileExistsError(output_dir)
        shutil.rmtree(output_dir)

    # Git
    offline_repository = git.Repo(offline_repository_dir)

    application_dir = os.path.join(output_dir, 'application_repository')
    application_repository = prepare_application_repository(application_dir,
                                                            application_repository_url,
                                                            application_repository_reference,
                                                            application_patch_file)

    # Package info
    info_file = os.path.join(output_dir, 'package.info')
    create_package_info_file(info_file, [application_repository, offline_repository], build_version, metadata)

    # packages layout as dictionaries. <file> : <file location under tar archive>
    sw_content = {
        os.path.join(offline_repository_dir, 'ansible'): 'ansible',
        application_configuration: 'ansible/application/application_configuration.yml',
        application_patch_role: 'ansible/application/onap-patch-role',
        os.path.join(application_dir, application_charts_dir): 'ansible/application/helm_charts',
        info_file: 'package.info'
    }
    resources_content = {
        resources_directory: '',
        info_file: 'package.info'
    }
    aux_content = {
        aux_directory: '',
        info_file: 'package.info'
    }

    if not skip_sw:
        log.info('Building offline installer')
        os.chdir(os.path.join(offline_repository_dir, 'ansible', 'docker'))
        installer_build = subprocess.run(
            os.path.join(offline_repository_dir, 'ansible', 'docker', 'build_ansible_image.sh'))
        installer_build.check_returncode()
        os.chdir(script_location)
        sw_package_tar_path = os.path.join(output_dir, 'sw_package.tar')
        create_package(sw_content, sw_package_tar_path)

    if not skip_resources:
        log.info('Building own dns image')
        dns_build = subprocess.run([
            os.path.join(offline_repository_dir, 'build', 'creating_data', 'create_nginx_image', '01create-image.sh'),
            os.path.join(resources_directory, 'offline_data', 'docker_images_infra')])
        dns_build.check_returncode()

        # Workaround for downloading without "flat" option
        log.info('Binaries - workaround')
        download_dir_path = os.path.join(resources_directory, 'downloads')
        os.chdir(download_dir_path)
        for file in os.listdir(download_dir_path):
            if os.path.islink(file):
                os.unlink(file)

        rke_files = glob.glob(os.path.join('.', '**/rke_linux-amd64'), recursive=True)
        os.symlink(rke_files[0], os.path.join(download_dir_path, rke_files[0].split('/')[-1]))

        helm_tar_files = glob.glob(os.path.join('.', '**/helm-*-linux-amd64.tar.gz'), recursive=True)
        os.symlink(helm_tar_files[0], os.path.join(download_dir_path, helm_tar_files[0].split('/')[-1]))

        kubectl_files = glob.glob(os.path.join('.', '**/kubectl'), recursive=True)
        os.symlink(kubectl_files[0], os.path.join(download_dir_path, kubectl_files[0].split('/')[-1]))

        os.chdir(script_location)
        # End of workaround

        resources_package_tar_path = os.path.join(output_dir, 'resources_package.tar')
        create_package(resources_content, resources_package_tar_path)

    if not skip_aux:
        aux_package_tar_path = os.path.join(output_dir, 'aux_package.tar')
        create_package(aux_content, aux_package_tar_path)

    add_checksum_info(output_dir)
    shutil.rmtree(application_dir)


def run_cli():
    """
    Run as cli tool
    """
    parser = argparse.ArgumentParser(description='Create Package For Offline Installer')
    parser.add_argument('--build-version',
                        help='version of the build', default='')
    parser.add_argument('application_repository_url', metavar='application-repository-url',
                        help='git repository hosting application helm charts')
    parser.add_argument('--application-repository_reference', default='master',
                        help='git refspec for repository hosting application helm charts')
    parser.add_argument('--application-patch_file',
                        help='git patch file to be applied over application repository', default='')
    parser.add_argument('--application-charts_dir',
                        help='path to directory under application repository containing helm charts ',
                        default='kubernetes')
    parser.add_argument('--application-configuration',
                        help='path to application configuration file (helm override configuration)',
                        default=os.path.join(offline_repository_dir, 'config/application_configuration.yml'))
    parser.add_argument('--application-patch-role',
                        help='path to application patch role file (ansible role) to be executed right before installation',
                        default='')
    parser.add_argument('--output-dir', '-o', default=os.path.join(offline_repository_dir, '../packages'),
                        help='Destination directory for saving packages')
    parser.add_argument('--resources-directory', default=os.path.join(offline_repository_dir, '../resources'),
                        help='Path to resource directory')
    parser.add_argument('--aux-directory',
                        help='Path to aux binary directory', default='')
    parser.add_argument('--skip-sw', action='store_true', default=False,
                        help='Set to skip sw package generation')
    parser.add_argument('--skip-resources', action='store_true', default=False,
                        help='Set to skip resources package generation')
    parser.add_argument('--skip-aux', action='store_true', default=False,
                        help='Set to skip aux package generation')
    parser.add_argument('--overwrite', action='store_true', default=False,
                        help='overwrite files in output directory')
    parser.add_argument('--debug', action='store_true', default=False,
                        help='Turn on debug output')
    parser.add_argument('--add-metadata', nargs="+", type=metadata_validation,
                        help='additional metadata added into package.info, format: key=value')
    args = parser.parse_args()

    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
    else:
        logging.basicConfig(stream=sys.stdout, level=logging.INFO, format='%(message)s')

    build_offline_deliverables(args.build_version,
                               args.application_repository_url,
                               args.application_repository_reference,
                               args.application_patch_file,
                               args.application_charts_dir,
                               args.application_configuration,
                               args.application_patch_role,
                               args.output_dir,
                               args.resources_directory,
                               args.aux_directory,
                               args.skip_sw,
                               args.skip_resources,
                               args.skip_aux,
                               args.overwrite,
                               args.add_metadata)


if __name__ == '__main__':
    run_cli()
