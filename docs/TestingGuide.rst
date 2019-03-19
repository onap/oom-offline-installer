.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. Copyright 2019 Samsung Electronics Co., Ltd.

OOM ONAP Offline Installer Testing Guide
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This testing guide describes how offline installer can be tested in local
development environment (laptop) without the need for actual servers.

Documentation refers to files/directories in ``ansible`` directory of this repository.

Introduction
============

Offline installer uses Molecule Molecule_ for testing all roles.

Molecule is integration testing tool for ansible roles. Role code is tested against
simulated host.

Molecule is designed to test single Ansible_ role in isolation. Offline installer however
has many small roles that are dependent on each other and also execution order for roles
is meaningful. In that respect Molecule's desing does not offer sufficiant level
of testing as it's lacking playbook level of scenario testing by default.
Luckily Molecule is highly configurable and it is possible to achieve a higher level of
testing scenarios for the offline installer.

Testing with Molecule is divided to two levels of testing:
	1) role level testing (as per Molecule desing)
	2) playbook level testing (offline installer own setup)

Purpose
=======

Purpose of using testing framework like Molecule is to make possible for developer to
verify ansible code changes locally in own laptop without the need for big resources.

Developer is also expected to do development of the Ansible code and the Molecule test
code at the same time.
Offline installer does not have unittest level of testing for the ansible code.

Any commit made to ansible code base needs to first pass Molecule tests before merged.

Test levels
===========

To cover both testing levels (role and playbook) with maximum benefit with minimum
copy-pasting, the testing code should be written in re-usable way.

Reusable test code can be achieved by writing all prepare/cleanup and other
helping code as a roles into main test directory.
Also testinfra_ test code can be shared between different roles and between different scenarios
of one role.

Testing of role and one scenario (one execution run of molecule) is fully
defined by **molecule.yml** file.

molecule.yml file is always located in directory:

	<tested-role>/molecule/<scenario>/molecule.yml

i.e. one role can have multiple scenarios (different configuration, OS etc. whatever user wants)
to execute tests for same role. Each scenario has own molecule.yml file and own testinfra
tests.

Molecule.yml file is the only file that cannot be re-used (except with symbolic links) but
all other resources can be re-used by referencing those in molecule.yml file or/and indirectly
from resources molecule.yml is pointing to.

**tested-role** is clear in case of normal role level testing, but in playbook level testing the
tested-role is just an invented role name and directory with molecule directory inside but no
actual ansible role code.

Role level testing
------------------

Purpose is to test single role in isolation just like Molecule is designed.
Role level testing is supposed to cover:

- Syntax checking (ymllint_, `Ansible lint`_, flake8_)
- Ansible code testing
- Idempotence testing
- Verifying role results from target hosts (testinfra tests)

Ansible code testing can/should also cover all different options how this role
can be run (`scenario <https://molecule.readthedocs.io/en/latest/configuration.html#root-scenario>`_).
Different molecule runs can be implemented as own scenarios (in addition to default scenario)
or default scenario playbook can be extended to run role tests multiple times just adjusting
configuration between.

Example with nexus role
::

    ├── infrastructure.yml
    ├── roles
    │   ├── nexus
    │   │   ├── defaults
    │   │   ├── files
    │   │   ├── molecule
    │   │   │   └── default
    │   │   │       ├── molecule.yml
    │   │   │       ├── playbook.yml
    │   │   │       ├── prepare.yml
    │   │   │       └── tests
    │   │   ├── tasks
    │   │   └── vars

Playbook level testing
----------------------

Playbook level testing is this project's (offline installer) own
setup and way of using Molecule. The target is to raise testing level
from single role testing up to single playbook testing.

Playbook level testing can be used also to run multiple playbooks and/or
playbooks multiple times with different configuration.

The aim is to verify multiple roles working together i.e. higher level of
integration testing.

Practically the **tested-role** is just a wrapper directory to conform
molecule required directory structure and provide a name for the test.
Directory itself does not contain and ansible role code, but just
molecule files configured to run multiple other roles.

Playbook level test directories should be named consistently according to
tested playbook and prefix string ``play`` and with optional description
if there are multiple scenarios for single playbook:

    play-<playbookname>[-<description>]

E.g.

- ``play-infrastructure``
- ``play-resources``

As role's are tested with own molecule tests in isolation, playbook level tests
should focus to integration of the roles and should avoid of repeating same tests
as done already for individual roles.

Playbook level testing is supposed to cover:
	- Ansible code testing

Basically it's easier to highlight what is supposed to be **avoided** in playbook level
testing for the reason not to repeat the same that is done already in role level testing.

- Syntax checking is left out already by default as molecule does linting only for the
  role code where molecule is run, and in this case tested-role is empty.

- Idempotence can be tested, but should be disabled (by default) in molecule.yml because
  it takes some much time and was tested already for individual roles.

- Verifying target hosts with testinfra tests can be done but then something else
  should be tested as in role based tests. And if those 2 would overlap it's better
  to leave them out.

Example with infrastructure playbook level test files
::

    ├── infrastructure.yml
    └── test
        ├── play-infrastructure
        │   └── molecule
        │       └── default
        │           ├── molecule.yml
        │           ├── playbook.yml
        │           ├── prepare.yml
        │           └── tests

Test code re-use and naming
===========================

As both testing levels test the same Ansible roles, there are a need
to share common code for both of them.

Testinfra_ Python code should be shared when also playbook level
tests verify target hosts. However sharing is not limited only for the 2 test levels
but also between different roles.

Individual role have testinfra tests on directory:

    roles/<role>/molecule/<scenario>/tests

and any commonly usable testinfra Python code should be placed to directory:

    test/testinfra

Ansible role testing uses several resources defined by provisioner section of
molecule.yml
https://molecule.readthedocs.io/en/latest/configuration.html#provisioner

Most common resources that are written for role testing are:

- playbook.yml  (mandatory but can include specific code)
- prepare.yml
- cleanup.yml
- create.yml
- destroy.yml

all of which can be just placed to scenario directory together with playbook.yml
(without editing molecule.yml when in default directory) and all of which can
include ansible code to do something e.g. prepare role for testing.

Example molecule files:

Role level tests for nexus role:
	- roles/nexus/molecule/default/molecule.yml
	- roles/nexus/molecule/default/playbook.yml
	- roles/nexus/molecule/default/prepare.yml
playbook level tests for infrastructure playbook:
	- test/play-infrastructure/molecule/default/molecule.yml
	- test/play-infrastructure/molecule/default/playbook.yml
	- test/play-infrastructure/molecule/default/prepare.yml

Sharing all test code should be done by writing them in the form of ansible
roles and placing commonly usable roles into:

  	test/roles/<testrole>

Test roles should be named consistently according to action it's needed and
role for it's for together with optional description:

    <action>-<role>[-<description>]

Examples of commonly used test roles
::

    ├── infrastructure.yml
    └── test
        ├── play-infrastructure
        └── roles
            ├── post-certificates
            ├── prepare-common
            ├── prepare-dns
            ├── prepare-docker
            ├── prepare-nexus
            └── prepare-nginx

Molecule images
===============

Molecule can build images of the tested hosts on the fly with default
Dockerfile template (docker driver) or from a Dockerfile provided by user.
In case of Vagrant driver used box image can be also fully customized by user.

To speed up testing it's preferred to pre-build needed images to be usable in
local docker repository in case of docker driver or Vagrant image cache in case
of Vagrant driver.

Used Dockerfiles/Box definitions are kept in following directory structure
::

    └── test
        ├── images
        │   ├── docker
        │   │   ├── centos6
        │   │   ├── centos7
        │   │   │   ├── dbus.service
        │   │   │   └── Dockerfile
        │   │   └── ubuntu16.04
        │   └── vagrant

Build images with following command:
    TBD

Usage
=====

Basic usage of molecule tests. See more detailed instructions from Molecule_

Run complete testing for a role or a playbook:

1. cd roles/<role> or cd test/play-<playbook-name>
2. molecule test

Develop a role code and run testing during the coding:

1. cd roles/<role>
2. Edit ansible code and molecule test code when needed
3. molecule converge
4. Repeate steps 2 and 3 untill code is ready and molecule tests are passing
5. molecule test

.. _Molecule: https://molecule.readthedocs.io
.. _Testinfra: https://testinfra.readthedocs.io
.. _Flake8: http://flake8.pycqa.org
.. _Yamllint: https://github.com/adrienverge/yamllint
.. _Ansible Lint: https://github.com/ansible/ansible-lint
.. _Ansible: https://www.ansible.com/
