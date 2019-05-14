*****************************************
vFWCL on Casablanca ONAP offline platform
*****************************************

|image0|
 
This document is collecting notes we have from running vFirewall demo on offline Casablanca platform
installed by ONAP offline installer tool.

We were able to finish the vFirewall demo use case manually (only) by
combining multiple ONAP Wiki sources, videos and Jira tickets as well as following
onap-discuss mailing list as some issues were already detected by other teams.

Some of the most relevant materials are available on following links:

* `https://www.youtube.com/watch?v=2Wo5iHWnoKM <https://www.youtube.com/watch?v=2Wo5iHWnoKM>`_
* `https://wiki.onap.org/display/DW/ONAP+Beijing%3A+Understanding+the+vFWCL+use-case+mechanism <https://wiki.onap.org/display/DW/ONAP+Beijing%3A+Understanding+the+vFWCL+use-case+mechanism>`_ 
* `https://wiki.onap.org/display/DW/vFWCL+instantiation%2C+testing%2C+and+debuging <https://wiki.onap.org/display/DW/vFWCL+instantiation%2C+testing%2C+and+debuging>`_ 
* `https://docs.onap.org/en/casablanca/submodules/integration.git/docs/docs_vfw.html <https://docs.onap.org/en/casablanca/submodules/integration.git/docs/docs_vfw.html>`_ 
 

.. contents:: Table of Contents
   :depth: 2


 
Step 1. Preconditions - before ONAP deployment
==============================================

Understanding of the underlying OpenStack deployment is required from anyone applying these instructions.

In addition, installation-specific location of the helm charts on the infra node must be known.
In this document it is referred to as <helm_charts_dir>

Snippets below are describing areas we need to configure for successfull vFWCL demo.

Pay attention to them and configure it (ideally before deployment) accordingly.

**1) <helm_charts_dir>/onap/values.yaml**::

        appc:
          enabled: true
          config:
             openStackType: OpenStackProvider
             openStackName: OpenStack
             openStackKeyStoneUrl: "http://10.20.30.40:5000“
             openStackServiceTenantName: “services“
             openStackDomain: "default“
             openStackUserName: "onap-tieto“
             openStackEncryptedPassword: "f7920677e15e2678b0f33736189e8965"
        …
        robot:
          enabled: true
          config:
            #openStackEncryptedPasswordHere should match the encrypted string used in SO and APPC and overridden per environment
            openStackEncryptedPasswordHere: "f7920677e15e2678b0f33736189e8965"
        …
        so:
          enabled: true
          replicaCount: 1
          liveness:
            # necessary to disable liveness probe when setting breakpoints
            # in debugger so K8s doesn't restart unresponsive container
            enabled: true
          # so server configuration
          config:
            # message router configuration
            dmaapTopic: "AUTO"
            # openstack configuration
            openStackUserName: "onap-tieto" 
            openStackRegion: "RegionOne"
            openStackKeyStoneUrl: "http://10.20.30.40:5000"
            openStackServiceTenantName: "services"
            openStackEncryptedPasswordHere: "f7920677e15e2678b0f33736189e8965"
 

**2) <helm_charts_dir>/robot/values.yaml**::

        #################################################################
        # Application configuration defaults.
        #################################################################

        config:
          openStackEncryptedPasswordHere: "c124921a3a0efbe579782cde8227681e"

        demoArtifactsVersion: "1.3.0"
        demoArtifactsRepoUrl: "https://nexus.onap.org/content/repositories/releases"
        openStackFlavourMedium: "m1.medium"
        openStackKeyStoneUrl: "http://10.20.30.40:5000"
        openStackPublicNetId: "9403ceea-0738-4908-a826-316c8541e4bb"  # this is not necessarily public network, robot script assumes that floating IPs can be created in that and that network’s name is „public“
        openStackPassword: "some_good_password"
        openStackRegion: "RegionOne"
        openStackTenantId: "b1ce7742d956463999923ceaed71786e"
        openStackUserName: "onap-tieto"
        openStackProjectName: "onap-tieto"
        openStackDomainId: "default"
        openStackKeystoneAPIVersion: "v2.0"
        ubuntu14Image: "vfwcl_trusty" # this is modified trusty image we are using with prepopulated honeycomb SW
        ubuntu16Image: "ubuntu-16.04-server-cloudimg-amd64" # not relevant, vfwcl is on trusty
        scriptVersion: "1.3.0"
        openStackPrivateNetId: "3c7aa2bd-ba14-40ce-8070-6a0d6a617175" # needs to be matching and already existing network in Openstack
        openStackSecurityGroup: "onap_sg"  # needs to be matching and already created in Openstack
        openStackPrivateSubnetId: "2bcb9938-9c94-4049-b580-550a44dc63b" # needs to be matching and already created in Openstack
        openStackPrivateNetCidr: "10.0.0.0/16" # we probably needs whole 10.0.x.x range as more 10.0.x, 10.0.y Ips are needed for VFW VMs
        openStackOamNetworkCidrPrefix: "10.0" # this is hardcoded in robot preload scripts
        vidServerProtocol:  "http"
        vidServerPort:  "8080"
        vnfPubKey: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDPwF2bYm2QuqZpjuAcZDJTcFdUkKv4Hbd/3qqbxf6g5ZgfQarCi+mYnKe9G9Px3CgFLPdgkBBnMSYaAzMjdIYOEdPKFTMQ9lIF0+i5KsrXvszWraGKwHjAflECfpTAWkPq2UJUvwkV/g7NS5lJN3fKa9LaqlXdtdQyeSBZAUJ6QeCE5vFUplk3X6QFbMXOHbZh2ziqu8mMtP+cWjHNBB47zHQ3RmNl81Rjv+QemD5zpdbK/h6AahDncOY3cfN88/HPWrENiSSxLC020sgZNYgERqfw+1YhHrclhf3jrSwCpZikjl7rqKroua2LBI/yeWEta3amTVvUnR2Y7gM8kHyh Generated-by-Nova"
        dcaeCollectorIp: "10.8.8.22" # need to use one of k8s host ip’s (ves collector will be listening on port 30205 on it)

 
**3) <helm_charts_dir>/so/charts/so-openstack-adapter/values.yaml**::

        config:
          openStackUserName: "onap-tieto"
          openStackRegion: "RegionOne"
          openStackKeyStoneUrl: "http://10.20.30.40:5000/v2.0"
          openStackServiceTenantName: "services"
          openStackEncryptedPasswordHere: "f7920677e15e2678b0f33736189e8965"
          openStackTenantId: "b1ce7742d956463999923ceaed71786e"

**4)  <helm\_charts\_dir>/policy/resources/config/pe/push-policies.sh**::

        echo "Upload BRMS Param Template"

        sleep 2

        # adding --no-check-certificate
        wget -O cl-amsterdam-template.drl https://git.onap.org/policy/drools-applications/plain/controlloop/templates/archetype-cl-amsterdam/src/main/resources/archetype-resources/src/main/resources/__closedLoopControlName__.drl?h=casablanca --no-check-certificate

        sleep 2

 

Step 2. Preconditions - after ONAP deployment
=============================================
 

Run HealthChecks after successful deployment, all of them must pass

Relevant robot scripts are under <helm_charts_dir>/oom/kubernetes/robot

::

        [root@tomas-infra robot]# ./ete-k8s.sh onap health

        51 critical tests, 51 passed, 0 failed
        51 tests total, 51 passed, 0 failed

 

Hints while troubleshooting issues:

*(1) increasing verbosity of robot regarding keystone credentials*

Note:  401 issues with robot_init might be troubleshoot just with that tweak

patch consists of replacing

::

        VARIABLES=

with

::

        VARIABLES="--removekeywords name:keystone\_interface.\*"

in runTags.sh

e.g.

::

        kubectl cp -n onap runTags.sh onap-robot-robot-5576c8f6cc-znvdp:/var/opt/OpenECOMP_ETE/runTags.sh
        root@onap-robot-robot-5576c8f6cc-znvdp:/var/opt/OpenECOMP_ETE# chmod +x runTags.sh
 

*(2) hint for editing configmap / faster testing changes in robot/values.yml*

e.g.

::

        [root@tomas-infra robot]# kubectl edit configmap onap-robot-robot-eteshare-configmap -n onap

*(3) very useful page describing commands for manual checking of HC’s*

`https://wiki.onap.org/display/DW/Robot+Healthcheck+Tests+on+ONAP+Components#RobotHealthcheckTestsonONAPComponents-ApplicationController(APPC)Healthcheck <https://wiki.onap.org/display/DW/Robot+Healthcheck+Tests+on+ONAP+Components#RobotHealthcheckTestsonONAPComponents-ApplicationController(APPC)Healthcheck>`_

 

Step 3. init_robot
==================
 

In this step we initialize robot apache server for accessing robot logs via browser

# demo-k8s.sh is also located under <helm_charts_dir>/oom/kubernetes/robot

::

        root@tomas-infra robot]# ./demo-k8s.sh onap init_robot

        Number of parameters:         2
        KEY:         init_robot
        WEB Site Password for user 'test': ++ kubectl --namespace onap get pods
        ++ sed 's/ .\*//'
        ++ grep robot
        + POD=onap-robot-robot-5576c8f6cc-znvdp
        + ETEHOME=/var/opt/OpenECOMP_ETE
        ++ kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-znvdp --
        bash -c 'ls -1q /share/logs/ | wc -l'
        + export GLOBAL_BUILD_NUMBER=18
        + GLOBAL_BUILD_NUMBER=18
        ++ printf %04d 18
        + OUTPUT_FOLDER=0018_demo_init_robot
        + DISPLAY_NUM=108
        + VARIABLEFILES='-V /share/config/vm_properties.py -V /share/config/integration\_robot\_properties.py -V /share/config/integration\_preload\_parameters.py'
        + kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-znvdp --/var/opt/OpenECOMP\_ETE/runTags.sh -V /share/config/vm\_properties.py -V /share/config/integration\_robot\_properties.py -V /share/config/integration\_preload\_parameters.py -v WEB\_PASSWORD:test -d /share/logs/0018_demo_init_robot -i UpdateWebPage --display 108
        Starting Xvfb on display :108 with res 1280x1024x24
        Executing robot tests at log level TRACE
        ==============================================================================
        Testsuites
        ==============================================================================
        Testsuites.Update Onap Page :: Initializes ONAP Test Web Page and Password
        ==============================================================================
        Update ONAP Page                                                      | PASS |
        ------------------------------------------------------------------------------
        Testsuites.Update Onap Page :: Initializes ONAP Test Web Page and ... | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Testsuites                                                            | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Output:  /share/logs/0018_demo_init_robot/output.xml
        Log:     /share/logs/0018_demo_init_robot/log.html
        Report:  /share/logs/0018_demo_init_robot/report.html
 

After enabling this, robot starts listening on port 30209 within k8s cluster

::

        root@hypervisor-tieto ~]# ssh root@1.2.3.4 -i ~/michal1_new_key -L 1235:127.0.0.1:1235

        root@tomas-infra ~]# ssh tomas-node0 -L 1235:127.0.0.1:30209

|image1|



Hints while troubleshooting issues:
 
Most common problems (i.e. 401 response) are coming from wrong openstack credentials in robot/values.yaml.



Step 4. robot init - demo services distribution
==================================================

Run following robot script to execute both init_customer + distribute

::

        #  demo-k8s.sh <namespace> init

        [root@tomas-infra robot]# ./demo-k8s.sh onap init
        Number of parameters:         2
        KEY:         init
        ++ kubectl --namespace onap get pods
        ++ sed 's/ .\*//'
        ++ grep robot
        + POD=onap-robot-robot-5576c8f6cc-lqpd7
        + ETEHOME=/var/opt/OpenECOMP_ETE
        ++ kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-lqpd7 --
        bash -c 'ls -1q /share/logs/ | wc -l'
        + export GLOBAL_BUILD_NUMBER=3
        + GLOBAL_BUILD_NUMBER=3
        ++ printf %04d 3
        + OUTPUT_FOLDER=0003_demo_init
        + DISPLAY_NUM=93
        + VARIABLEFILES='-V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py'
         kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-lqpd7 -- /var/opt/OpenECOMP_ETE/runTags.sh -V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py -d /share/logs/0003_demo_init -i InitDemo --display 93
        Starting Xvfb on display :93 with res 1280x1024x24
        Executing robot tests at log level TRACE
        ==============================================================================
        Testsuites
        ==============================================================================
        Testsuites.Demo :: Executes the VNF Orchestration Test cases including setu ...
        ==============================================================================
        Initialize Customer And Models
        Distributing vFWCL
        Downloaded:service-Demovfwcl-csar.csar
        Distibuting vLB
        Distibuting vCPEInfra
        Downloaded:service-Demovcpeinfra-csar.csar
        Distibuting vCPEvBNG
        Downloaded:service-Demovcpevbng-csar.csar
        Distibuting vCPEvBRGEMU
        Downloaded:service-Demovcpevbrgemu-csar.csar
        Distibuting vCPEvGMUX
        Downloaded:service-Demovcpevgmux-csar.csar
        Distibuting vCPEvGW (this is not vCPEResCust service)
        Downloaded:service-Demovcpevgw-csar.csar
        | PASS |
        ------------------------------------------------------------------------------
        Testsuites.Demo :: Executes the VNF Orchestration Test cases inclu... | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Testsuites                                                            | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Output:  /share/logs/0003_demo_init/output.xml
        Log:     /share/logs/0003_demo_init/log.html
        Report:  /share/logs/0003_demo_init/report.html

 

Step 5. Deploy vFW service
==========================
 

Now we need to verify that vFWCL service is distributed, we would need to start using GUI for that.
We can either make ssh tunnel to respective ports, create SOCKS proxy or use VNC server on infra node.

.. note:: VNC server is installed as a part of offline platform to help with accessing ONAP GUIs.

Portal GUI should be reachable under following link:

`http://portal.api.simpledemo.onap.org:30215/ONAPPORTAL/login.htm <http://portal.api.simpledemo.onap.org:30215/ONAPPORTAL/login.htm>`_


.. note:: VNC way: need to get /etc/hosts updated on infra, which requires restart of dnsmasq container. IP’s of particular services should match with k8s node where service is present


e.g.

::

        root@tomas-infra files]# cat /etc/hosts
        
        127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
        ::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
        10.8.8.22   tomas-node0
        10.8.8.9    tomas-node1
        10.8.8.19   tomas-node2

        10.8.8.19    portal.api.simpledemo.onap.org
        10.8.8.9     vid.api.simpledemo.onap.org
        10.8.8.19    sdc.api.fe.simpledemo.onap.org
        10.8.8.22    portal-sdk.simpledemo.onap.org
        10.8.8.19    policy.api.simpledemo.onap.org
        10.8.8.9     aai.api.sparky.simpledemo.onap.org
        10.8.8.9     cli.api.simpledemo.onap.org
        10.8.8.9     msb.api.discovery.simpledemo.onap.org


 vnc server must be running

::

        [root@tomas-infra files]# docker ps

        CONTAINER ID        IMAGE                           COMMAND                   CREATED             STATUS             PORTS                                                             NAMES
        71821578bc32        rancher/server:v1.6.22          "/usr/bin/entrysh..."     8 days ago          Up 8 days          3306/tcp, 0.0.0.0:8080->8080/tcp                                  rancher-server
        6241e0f86f71        sonatype/nexus3:3.15.2          "sh -c ${SONATYPE\_..."   8 days ago          Up 8 days          8081/tcp                                                          nexus
        b36f666e4ba0        own_nginx:2.0.0                 "/bin/sh -c 'spawn..."    8 days ago          Up 7 hours         0.0.0.0:80->80/tcp,0.0.0.0:443->443/tcp, 0.0.0.0:10001->443/tcp   nginx-server
        6e161228f43e        consol/centos-icewm-vnc:1.2.0   "/dockerstartup/vn..."    8 days ago          Up 8 days          0.0.0.0:5901->5901/tcp, 0.0.0.0:6901->6901/tcp                    vnc-server
        00a496f85dcd        andyshinn/dnsmasq:2.76          "dnsmasq -k -H /si..."    8 days ago          Up 8 days                                                                            dns-server


Browsers need some security exceptions – *enabled mixed content*

# HowTo enable mixed content

`https://kb.iu.edu/d/bdny <https://kb.iu.edu/d/bdny>`_

 
**Action: deploy vFWCL service (should be in DISTRIBUTION_COMPLETE_OK state)**

This step is done via Virtual Infrastructure Designer (VID), which *can not be opened* via Portal directly in Casablanca (see
\ `https://jira.onap.org/browse/PORTAL-555 <https://urldefense.proofpoint.com/v2/url?u=https-3A__jira.onap.org_browse_PORTAL-2D555&d=DwMFoQ&c=LFYZ-o9_HUMeMTSQicvjIg&r=P9yc3y-ZUtmQKjhXoKwlVB81dNDgHvk04cBUt5jCEcQ&m=JzFxeZODOHqDP4wAZ04KmGPfiO7Z8bAYJEuT_VRk2Q8&s=GLgO4vYtl1AbLaZNU7UDqJ1-4urwtq0T8nANSb72JTo&e=>`__).
As described in the ticket, it can be nevertheless opened by going directly to the address that Portal is showing as failing.

|image2|

|image3|

|image4|


**Action: get Service Instance ID (this id will be used at step nr.9 for heatbridge)**

|image5|

e.g. d99c5026-719a-432d-b5bd-a25dc2cf6a4b


Step 6. Instantiate services
============================
 

For instantiating service, we need to discover which Id is matching to which vFirewall VNF.

|image6|

We can obtain it from csar file by the following steps (as described in following recording https://www.youtube.com/watch?v=2Wo5iHWnoKM)

* Login to SDC as designer (cs0008 / demo123456!)
* Open demoVFWCL service and its TOSCA artifacts tab
* Click on Download icon next to TOSCA_CSAR

|image7|

Csar file can be opened e.g. using midnight-commander, browse it and go to ./Definitions folder

Various yml files will be there, from example below one can see that

|image8|

vPKG VNF has id D5724ce5Ae8a4175B48d

and 

vFW VNF  has id E48fe0e2Dd744f2891dc

**Check the following expected problems before creating node instances:**

Service instantiation will not work out of the box, the following tickets
require workarounds described below to make the instantiation succeed.

**Issue 1: TEST-133**

|image9|

This problem was reported in

`https://jira.onap.org/browse/TEST-133 <https://jira.onap.org/browse/TEST-133>`_

fix is tracked in

`https://jira.onap.org/browse/INT-705 <https://jira.onap.org/browse/INT-705>`_

but won’t be available in Casablanca.

::

        2019-04-30T08:11:05.320Z|effc1fb9-84d0-462b-9c27-20eb6b04dc8a|camundaTaskExecutor-1|AssignVnfBB||||ERROR|300|Error
        from SDNC: No availability zones found in AAI for cloud region  RegionOne
        |Error from SDNC: No availability zones found in AAI for cloud region RegionOne

 

!! More logs can be found in BPMN !!

::

        [root@tomas-infra ~]# kubectl exec -it onap-so-so-bpmn-infra-6d57c84c7f-rdd59 -n onap sh 
        /app/logs/bpmn

 

**It is a deficiency of the robot test case in Casablanca and we need to add missing availability zone to the cloud region manually**

e.g.

::

        # to be executed on infra node
        # to insert availability zone

        [root@tomas-infra ~]# curl -k -i -X PUT --user aai@aai.onap.org:demo123456! -H 'Accept: application/json' -H 'Content-Type: application/json' -H 'X-FromAppId: MSO' -H 'X-TransactionId: 89273498' -d '{"availability-zone-name": "AZ1", "hypervisor-type": "hypervisor"}' https://tomas-node0:30233/aai/v14/cloud-infrastructure/cloud-regions/cloud-region/CloudOwner/RegionOne/availability-zones/availability-zone/AZ1 --insecure

        HTTP/1.1 201 Created
        Date: Thu, 02 May 2019 19:35:26 GMT
        vertex-id: 266296
        Content-Type: application/json
        X-AAI-TXID: 1-aai-resources-190502-19:35:26:951-38024
        Content-Length: 0
        Strict-Transport-Security: max-age=16000000; includeSubDomains; preload;


::

        # to verify that availability zone has been added successfully

        [root@tomas-infra ~]# curl -k -i -X GET --user aai@aai.onap.org:demo123456! -H 'Accept: application/json' -H 'Content-Type: application/json' -H 'X-FromAppId: MSO' -H 'X-TransactionId: 89273498' -d '{"availability-zone-name": "AZ1", "hypervisor-type": "hypervisor"}' https://tomas-node0:30233/aai/v14/cloud-infrastructure/cloud-regions/cloud-region/CloudOwner/RegionOne/availability-zones/availability-zone/AZ1 --insecure

        HTTP/1.1 200 OK
        Date: Thu, 02 May 2019 19:35:32 GMT
        vertex-id: 266296
        Content-Type: application/json
        X-AAI-TXID: 1-aai-resources-190502-19:35:32:538-84201
        Content-Length: 98
        Strict-Transport-Security: max-age=16000000; includeSubDomains; preload;


**Issue 2: SO-1150**

Service creation (vFWSNK-1) is failing on error as follows (as seen in bpmn log):

::

        2019-04-30T14:14:08.707Z|22326334-bf04-45e8-adc7-2652349b23e4|camundaTaskExecutor-1|AssignVnfBB||BPMN|AssignVnfBB|ERROR|900|Exception in org.onap.so.bpmn.infrastructure.sdnc.tasks.SDNCAssignTasks.assignVnf |BPMN_GENERAL_EXCEPTION_ARG
        2019-04-30T14:17:07.665Z|bcb7687f-4e1d-4da8-861c-7d6239faedd6|camundaTaskExecutor-2|AssignVnfBB||BPMN|AssignVnfBB|ERROR|300|Error from SDNC: vnf-information.onap-model-information.model-customization-uuid is a required input|RA_RESPONSE_FROM_SDNC
        2019-04-30T14:17:07.666Z|bcb7687f-4e1d-4da8-861c-7d6239faedd6|camundaTaskExecutor-2|AssignVnfBB||||ERROR|300|Error from SDNC: **vnf-information.onap-model-information.model-customization-uuid**

        ** is a required input|Error from SDNC: vnf-information.onap-model-information.model-customization-uuid is a required input**
        org.onap.so.client.exception.BadResponseException: Error from SDNC: vnf-information.onap-model-information.model-customization-uuid is a required input

 
Issue is discussed in `https://jira.onap.org/browse/SO-1150 <https://jira.onap.org/browse/SO-1150>`_

The suggested WA to switch to old VNF_API in VID works
 

|image10|
 

**Action: As we have issues above fixed, we can fill form for both node instances as visible in screenshots below.**

|image11|\ |image12|

 
|image13|\ |image14|

 

Step 7. SDNC topology preload
=============================

We will use the demo_k8s.sh script again for this step. Some parts are hardcoded in the script for the preload keyword, but work well for our purposes.

::

        # demo_k8s.sh <namespace> preload <vnf_name> <module_name>
        # Preload data for VNF for the <module_name>

        [root@tomas-infra robot]# ./demo-k8s.sh onap preload vFWSNK-1 vFWSNK-Module-1

        Number of parameters:         4
        KEY:         preload
        ++ kubectl --namespace onap get pods
        ++ sed 's/ .\*//'
        ++ grep robot
        + POD=onap-robot-robot-5576c8f6cc-lqpd7
        + ETEHOME=/var/opt/OpenECOMP_ETE
        ++ kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-lqpd7 --
        bash -c 'ls -1q /share/logs/ | wc -l'
        + export GLOBAL_BUILD_NUMBER=6
        + GLOBAL_BUILD_NUMBER=6
        ++ printf %04d 6
        + OUTPUT_FOLDER=0006_demo_preload
        + DISPLAY_NUM=96
        + VARIABLEFILES='-V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py' 
        + kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-lqpd7 -- /var/opt/OpenECOMP_ETE/runTags.sh -V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py -v VNF_NAME:vFWSNK-1 -v MODULE_NAME:vFWSNK-Module-1 -d /share/logs/0006_demo_preload -i PreloadDemo --display 96
        Starting Xvfb on display :96 with res 1280x1024x24
        Executing robot tests at log level TRACE
        ==============================================================================
        Testsuites
        ==============================================================================
        Testsuites.Demo :: Executes the VNF Orchestration Test cases including
        setu...
        ==============================================================================
        Preload VNF                                                           | PASS |
        ------------------------------------------------------------------------------
        Testsuites.Demo :: Executes the VNF Orchestration Test cases inclu... | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Testsuites                                                            | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Output:  /share/logs/0006_demo_preload/output.xml
        Log:     /share/logs/0006_demo_preload/log.html
        Report:  /share/logs/0006_demo_preload/report.html


Similarly let's preload vPKG VNF sdnc profile 

::

        root@tomas-infra robot]# ./demo-k8s.sh onap preload vPKG-1 PKG-Module-1
        Number of parameters:        4
        KEY:         preload
        ++ kubectl --namespace onap get pods
        ++ sed 's/ .\*//'
        ++ grep robot
        + POD=onap-robot-robot-5576c8f6cc-lqpd7
        + ETEHOME=/var/opt/OpenECOMP\_ETE
        ++ kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-lqpd7 --
        bash -c 'ls -1q /share/logs/ | wc -l'
        + export GLOBAL_BUILD_NUMBER=7
        + GLOBAL_BUILD_NUMBER=7
        ++ printf %04d 7
        + OUTPUT_FOLDER=0007_demo_preload
        + DISPLAY_NUM=97
        + VARIABLEFILES='-V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py' 
        + kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-lqpd7 -- /var/opt/OpenECOMP_ETE/runTags.sh -V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py -v VNF_NAME:vPKG-1 -v MODULE_NAME:vPKG-Module-1 -d /share/logs/0007_demo_preload -i PreloadDemo --display 97
        Starting Xvfb on display :97 with res 1280x1024x24
        Executing robot tests at log level TRACE
        ==============================================================================
        Testsuites
        ==============================================================================
        Testsuites.Demo :: Executes the VNF Orchestration Test cases including
        setu...
        ==============================================================================
        Preload VNF                                                           | PASS |
        ------------------------------------------------------------------------------
        Testsuites.Demo :: Executes the VNF Orchestration Test cases inclu... | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Testsuites                                                            | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Output:  /share/logs/0007_demo_preload/output.xml
        Log:     /share/logs/0007_demo_preload/log.html
        Report:  /share/logs/0007_demo_preload/report.html

 

Step 8. Creating VF Modules
===========================

 
In this step vFW VMs are spawned in Openstack (VIM).

Instance Names which were used in SDNC preload step must be used also here

.. note:: vFWSNK-Module-1 must be created first and vFWPKG-Module-1 second.

|image15|

|image16|

End result of this step is 3 VMs created within 2 heat stacks in Openstack

|image17|

 
**Issue: VF’s spawning failed due to MSO being unable to talk to Keystone (using default keystone 1.2.3.4)**

**(this will not appear if OOM charts are configured properly, see step 1)**

Hint:  openstack credentials can be changed in so-mariadb directly (just when problem is there)

Note that in this context also keystone API version is expected:

e.g.

::

        IDENTITY_URL="http://10.20.30.40:5000/v2.0“

(ideally this should come from <helm_charts_dir>/so/charts/so-openstack-adapter/values.yaml)


::

        root@mariadb:/# mysql -u root -p # password is : password
        Enter password:
        Welcome to the MariaDB monitor.  Commands end with ; or \\g.
        Your MariaDB connection id is 51192
        Server version: 10.1.11-MariaDB-1~jessie-log mariadb.org binary distribution
        Copyright (c) 2000, 2015, Oracle, MariaDB Corporation Ab and others.
        Type 'help;' or '\\h' for help. Type '\\c' to clear the current input statement.

        MariaDB [(none)]> use catalogdb;

        Database changed
        MariaDB [catalogdb]> update identity_services set IDENTITY_URL="http://10.20.30.40:5000/v2.0" where ID="DEFAULT_KEYSTONE";

        Query OK, 1 row affected (0.01 sec)
        Rows matched: 1  Changed: 1  Warnings: 0
        MariaDB [catalogdb]> select \* from identity\_services;
        +------------------+----------------------------------------------+----------------------+----------------------------------+--------------+-------------+-----------------+----------------------+------------------------------+-----------------+---------------------+---------------------+
        | ID               | IDENTITY_URL                                 |        MSO_ID        | MSO_PASS                         | ADMIN_TENANT | MEMBER_ROLE | TENANT_METADATA | IDENTITY_SERVER_TYPE | IDENTITY_AUTHENTICATION_TYPE | LAST_UPDATED_BY | CREATION_TIMESTAMP  | UPDATE_TIMESTAMP    |
        +------------------+----------------------------------------------+----------------------+----------------------------------+--------------+-------------+-----------------+----------------------+------------------------------+-----------------+---------------------+---------------------+
        | DEFAULT_KEYSTONE | http://10.20.30.40:5000                      | vnf_user             | c124921a3a0efbe579782cde8227681e | service      | admin       |               1 | KEYSTONE             | USERNAME_PASSWORD            | FLYWAY          | 2019-04-29 09:13:56 | 2019-04-29 09:13:56 |
        | RAX_KEYSTONE     | https://identity.api.rackspacecloud.com/v2.0 | RACKSPACE_ACCOUNT_ID | RACKSPACE_ACCOUNT_APIKEY         | service      | admin       |               1 | KEYSTONE             | RACKSPACE_APIKEY             | FLYWAY          | 2019-04-29  9:13:56 | 2019-04-29 09:13:56 |
        +------------------+----------------------------------------------+----------------------+----------------------------------+--------------+-------------+-----------------+----------------------+------------------------------+-----------------+---------------------+---------------------+

         rows in set (0.00 sec)
        MariaDB [catalogdb]>

 

**Hint: ** deleting VF module from aai directly **** (e.g. when in "pending-delete“ state)

::

        [root@tomas-infra robot]# curl -i -X DELETE --user aai@aai.onap.org:demo123456! -H 'Accept: application/json' -H 'Content-Type: application/json' -H 'X-FromAppId: MSO' -H 'X-TransactionId: 89273498' https://tomas-node0:30233/aai/v14/network/generic-vnfs/generic-vnf/<vnfid>/vf-modules/vf-module/<vf-module-id>?resource-version=<version from VF info> --insecure


e.g.

::

        [root@tomas-infra robot]# curl -i -X DELETE --user aai@aai.onap.org:demo123456! -H 'Accept: application/json' -H 'Content-Type: application/json' -H 'X-FromAppId: MSO' -H 'X-TransactionId: 89273498' https://tomas-node0:30233/aai/v14/network/generic-vnfs/generic-vnf/959e279f-66be-463f-b9b0-078df5531c17/vf-modules/vf-module/ba07bae9-bc39-474f-aee6-69441f05f08f?resource-version=1556798583277 --insecure

**After this part we should have all 3 VMs running and this concludes the vFWCL instantiation part. Next parts are important for CL to actually happen.**


Step 9. Run heatbridge
======================


To distribute info to AAI about the VMs that were spawned in previous step to AAI]:

::

        ./demo-k8s.sh <namespace> heatbridge <stack_name> <service_instance_id> <service> <oam-ip-address>
        Run heatbridge against the stack for the given service instance and service where:
        - <stack_name> is the Instance Name used in SDNC Preload Step
        - <service_instance_id> is the id we checked from GUI
        - <service> is either vFWSNK or vPKG (hardcoded in robot scripts)
        - <oam-ip-address> is vfw_private_up_2 (see the Hint below)  


e.g.

::

        [root@tomas-infra robot]# ./demo-k8s.sh onap heatbridge vFWSNK-Module-1 d99c5026-719a-432d-b5bd-a25dc2cf6a4b vFWSNK 10.0.128.121


**Hint** : According to `https://wiki.onap.org/display/DW/IP+Addresses+in+AAI <https://wiki.onap.org/display/DW/IP+Addresses+in+AAI>`_
the ipv4-oam-address is obtained from vfw_private_ip_2 variable of the vLB which is in the vFWSNK VNF (vFWSNK/base_vfw.yaml)
which we can see from "openstack stack show"

e.g vfw_private_ip_2: 10.0.128.121                                                                       
                              
::

        [root@tomas-infra robot]# ./demo-k8s.sh onap heatbridge vFWSNK-Module-1 d99c5026-719a-432d-b5bd-a25dc2cf6a4b vFWSNK 10.0.128.121
        Number of parameters: 6
        KEY: heatbridge
        ++ kubectl --namespace onap get pods
        ++ sed 's/ .\*//'
        ++ grep robot
        + POD=onap-robot-robot-5576c8f6cc-rjbkf
        + ETEHOME=/var/opt/OpenECOMP_ETE
        ++ kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-rjbkf --
        bash -c 'ls -1q /share/logs/ | wc -l'
        + export GLOBAL_BUILD_NUMBER=15
        + GLOBAL_BUILD_NUMBER=15
        ++ printf %04d 15
        + OUTPUT_FOLDER=0015_demo_heatbridge
        + DISPLAY_NUM=105
        + VARIABLEFILES='-V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py' 
        + kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-rjbkf -- /var/opt/OpenECOMP_ETE/runTags.sh -V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V  /share/config/integration_preload_parameters.py -v HB_STACK:vFWSNK-Module-1 -v HB_SERVICE_INSTANCE_ID:d99c5026-719a-432d-b5bd-a25dc2cf6a4b -v HB_SERVICE:vFWSNK -v HB_IPV4_OAM_ADDRESS:10.0.128.121 -d /share/logs/0015_demo_heatbridge -i heatbridge --display 105
        Starting Xvfb on display :105 with res 1280x1024x24
        Executing robot tests at log level TRACE
        ==============================================================================
        Testsuites
        ==============================================================================
        Testsuites.Demo :: Executes the VNF Orchestration Test cases including
        setu...
        ==============================================================================
        Run Heatbridge :: Try to run heatbridge                              
        Set VNF ProvStatus: 4831ed46-a19f-4f7c-89b3-e078c3509138 to ACTIVE    | PASS |
        ------------------------------------------------------------------------------
        Testsuites.Demo :: Executes the VNF Orchestration Test cases inclu... | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Testsuites                                                            | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Output:  /share/logs/0015_demo_heatbridge/output.xml
        Log:     /share/logs/0015_demo_heatbridge/log.html
        Report:  /share/logs/0015_demo_heatbridge/report.html
 


We are not sure if AAI needs info from vPKG-Module-1 or not, information on wiki pages are contradicting. Nevertheless, the following can be done to be sure:
 
::

        [root@tomas-infra robot]# ./demo-k8s.sh onap heatbridge vPKG-Module-1 d99c5026-719a-432d-b5bd-a25dc2cf6a4b vPKG 10.0.128.121
        Number of parameters: 6
        KEY: heatbridge
        ++ kubectl --namespace onap get pods
        ++ sed 's/ .\*//'
        ++ grep robot
        + POD=onap-robot-robot-5576c8f6cc-rjbkf
        + ETEHOME=/var/opt/OpenECOMP_ETE
        ++ kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-rjbkf --
        bash -c 'ls -1q /share/logs/ | wc -l'
        + export GLOBAL_BUILD_NUMBER=16
        + GLOBAL_BUILD_NUMBER=16
        ++ printf %04d 16
        + OUTPUT_FOLDER=0016_demo_heatbridge
        + DISPLAY_NUM=106
        + VARIABLEFILES='-V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py'
        + kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-rjbkf -- /var/opt/OpenECOMP_ETE/runTags.sh -V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V  /share/config/integration_preload_parameters.py -v HB_STACK:vPKG-Module-1 -v HB_SERVICE_INSTANCE_ID:d99c5026-719a-432d-b5bd-a25dc2cf6a4b -v HB_SERVICE:vPKG -v HB_IPV4_OAM_ADDRESS:10.0.128.121 -d /share/logs/0016_demo_heatbridge -i heatbridge --display 106
        Starting Xvfb on display :106 with res 1280x1024x24
        Executing robot tests at log level TRACE
        ==============================================================================
        Testsuites
        ==============================================================================
        Testsuites.Demo :: Executes the VNF Orchestration Test cases including
        Setu...
        ==============================================================================
        Run Heatbridge :: Try to run heatbridge                              
        Set VNF ProvStatus: f611b9d5-8715-4963-baba-e9c06e1a80cb to ACTIVE    | PASS |
        ------------------------------------------------------------------------------
        Testsuites.Demo :: Executes the VNF Orchestration Test cases inclu... | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Testsuites                                                            | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Output:  /share/logs/0016_demo_heatbridge/output.xml
        Log:     /share/logs/0016_demo_heatbridge/log.html
        Report:  /share/logs/0016_demo_heatbridge/report.html


Step 10. Verify the existence of drools controller and facts
============================================================
 

Check that controller is enabled

::

        [root@tomas-infra policy]# kubectl exec -it onap-policy-drools-0 -n onap bash
        policy@onap-policy-drools-0:/tmp/policy-install$ policy status

        [drools-pdp-controllers]
         L []: Policy Management (pid 3839) is running
                21 cron jobs installed.
        [features]
        name                      version         status
        ----                      -------         ------
        controlloop-casablanca    1.3.7           disabled
        test-transaction          1.3.7           disabled
        eelf                      1.3.7           disabled
        healthcheck               1.3.7           enabled
        session-persistence       1.3.7           disabled
        pooling-dmaap             1.3.7           disabled
        active-standby-management 1.3.7           disabled
        controlloop-utils         1.3.7           disabled
        state-management          1.3.7           disabled
        controlloop-trans         1.3.7           enabled
        controlloop-amsterdam     1.3.7           enabled
        distributed-locking       1.3.7           enabled

        [migration]
        pooling: OK @ 1811

Alternatively using REST

::

        [root@tomas-infra policy]# curl -k --silent --user 'demo@people.osaaf.org:demo123456!' -X GET \ `https://tomas-node0:30221/policy/pdp/engine/controllers/amsterdam/drools <https://tomas-node0:30221/policy/pdp/engine/controllers/amsterdam/drools>`_


Amsterdam drools controller should also have facts available, which can be checked using REST:

::

        [root@tomas-infra policy]# curl -k --silent --user 'demo@people.osaaf.org:demo123456!' -X GET \ `https://tomas-node0:30221/policy/pdp/engine/controllers/amsterdam/drools/facts <https://tomas-node0:30221/policy/pdp/engine/controllers/amsterdam/drools/facts>`_


 
**If amsterdam controller is not enabled or facts can’t be found, follow instructions from** `PolicyInstallation <https://wiki.onap.org/display/DW/ONAP+Policy+Framework%3A+Installation+of+Amsterdam+Controller+and+vCPE+Policy>`_

**For installing amsterdam controller only – it should be noted that controlloop-utils feature must remain disabled as it’s used just for internal simulation as described in** `ClSimulation <https://docs.onap.org/en/latest/submodules/policy/engine.git/docs/platform/clsimulation.html>`_
**and will cause the real E2E use case to fail if activated.**


Step 11. Push policy
====================

**Issue:**

Demo policies are not pushed automatically due to following problem (this should not occur if OOM charts are patched before deployment as suggested in Step 1):

::

        policy@onap-policy-pap-7666c9b6bb-rkpz2:/tmp/policy-install$ /tmp/policy-install/config/push-policies.sh
        Upload BRMS Param Template
        --2019-05-09 13:13:44-- 
        https://git.onap.org/policy/drools-applications/plain/controlloop/templates/archetype-cl-amsterdam/src/main/resources/archetype-resources/src/main/resources/\_\_closedLoopControlName\_\_.drl?h=casablanca
        Resolving git.onap.org (git.onap.org)... 10.8.8.8
        Connecting to git.onap.org (git.onap.org)|10.8.8.8\|:443... connected.
        ERROR: cannot verify git.onap.org's certificate, issued by '/C=PL/ST=Poland/L=Krakow/O=Samsung':
          Unable to locally verify the issuer's authority.
        To connect to git.onap.org insecurely, use `--no-check-certificate'.

push_policies.sh script is mounted (in readOnly) to pap container

::

        "HostConfig": {
                "Binds": [
                        "/etc/localtime:/etc/localtime:ro",
        "/var/lib/kubelet/pods/90b0584e-70cd-11e9-a694-022ec4c4d330/volume-subpaths/pe-pap/pap/1:/tmp/policy-install/config/push-policies.sh:ro",
 

Therefore it can be patched even after deployment by executing following steps directly on kube node where the pap container is running:

::

        [root@tomas-infra pe]# kubectl get pods -n onap -o=wide | grep pap
        onap-policy-pap-7666c9b6bb-rkpz2                               2/2      
        Running      0          1d        10.42.110.165  
        tomas-node0.novalocal   <none>


        [root@tomas-infra pe]# ssh tomas-node0
        Last login: Thu May  9 13:32:13 2019 from gerrit.onap.org
        [root@tomas-node0 ~]# vi /var/lib/kubelet/pods/90b0584e-70cd-11e9-a694-022ec4c4d330/volume-subpaths/pe-pap/pap/1

 
and we can add missing --no-check-certificate to it

::

        wget -O cl-amsterdam-template.drl https://git.onap.org/policy/drools-applications/plain/controlloop/templates/archetype-cl-amsterdam/src/main/resources/archetype-resources/src/main/resources/__closedLoopControlName__.drl?h=casablanca --no-check-certificate


Afterwards we can re-run the push-policies.sh using:

::

        [root@tomas-infra pe]# kubectl exec -it onap-policy-pap-7666c9b6bb-rkpz2 -n onap bash
        Defaulting container name to pap.
        Use 'kubectl describe pod/onap-policy-pap-7666c9b6bb-rkpz2 -n onap' to see all of the containers in this pod.
        policy@onap-policy-pap-7666c9b6bb-rkpz2:/tmp/policy-install$ export PRELOAD_POLICIES=true
        policy@onap-policy-pap-7666c9b6bb-rkpz2:/tmp/policy-install$ /tmp/policy-install/config/push-policies.sh

To verify that policies were pushed correctly open **Policy Editor** as Demo user (note that this also does not work from Portal directly, see `https://jira.onap.org/browse/PORTAL-554 <https://urldefense.proofpoint.com/v2/url?u=https-3A__jira.onap.org_browse_PORTAL-2D554&d=DwMFoQ&c=LFYZ-o9_HUMeMTSQicvjIg&r=P9yc3y-ZUtmQKjhXoKwlVB81dNDgHvk04cBUt5jCEcQ&m=JzFxeZODOHqDP4wAZ04KmGPfiO7Z8bAYJEuT_VRk2Q8&s=1Pk0oDBJzpg_vV7MFmnTkYYNWCXmuVVASQ-RkrYelM0&e=>`_ 

move to **“com”** folder - if you see policies as in the screenshot (especially BRMSParamvFirewall and MicroServicevFirewall), policies were pushed correctly

|image18| 


Step 12. Update policy
======================


12.1 Obtain vPKG Invariant UUID (from TOSCA_CSAR file)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Download Tosca CSAR file:


- From ONAP-Portal’s SDC under Designer user
- move to demovFWCL Service
- open TOSCA Artifacts
- click download TOSCA_CSAR 


|image19|

- rename to .zip
- open csar e.g. in totalcommander and find part relevant for vPKG VNF

\\Definitions\\service-Demovfwcl-template.yml

and get invariantUUID from it

::

        topology_template: 
          node_templates:
            ad3826a0-36ff-4d7e-b393 0:
              type: org.openecomp.resource.vf.Ad3826a036ff4d7eB393
              metadata:
        invariantUUID: f4fa2471-167c-4353-81d5-7270eee74fe1
        UUID: 597650d2-c048-46a0-8324-bfe535d7f749
        customizationUUID:
        2f35722e-2934-451a-98e3-f0cf123fc48c




12.2 Update vFW policy script
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This step is automated within OOM in following script:

::

        oom/kubernetes/policy/charts/drools/resources/scripts/update-vfw-op-policy.sh

This script requires following params

::

        [root@tomas-infra scripts]# ./update-vfw-op-policy.sh
        Usage: update-vfw-op-policy.sh <k8s-host> <policy-pdp-node-port> <policy-drools-node-port> <resource-id>

        e.g.
        ./update-vfw-op-policy.sh 10.8.8.19 30237 30221 e32a234a-9701-44d0-b2c8-4d6c38b045c6

However it did not work for us, so we run it manually:

*(a) Delete original Firewall policy*

::

        [root@tomas-infra scripts]# kubectl exec -it onap-policy-pdp-0 -n onap bash
        policy@onap-policy-pdp-0:/tmp/policy-install$ curl -v -k -X DELETE --header 'Content-Type: application/json' --header 'Accept: text/plain' --header 'ClientAuth: cHl0aG9uOnRlc3Q=' --header 'Authorization: Basic dGVzdHBkcDphbHBoYTEyMw==' --header 'Environment: TEST' -d '{ "pdpGroup": "default", "policyComponent" : "PDP", "policyName": "com.BRMSParamvFirewall", "policyType": "BRMS\_Param" ' https://localhost:8081/pdp/api/deletePolicy

*(b) Update Firewall policy*

resource_id can be get from step 12.1

::

        RESOURCE_ID=f4fa2471-167c-4353-81d5-7270eee74fe1

        curl -v -k -X PUT --header 'Content-Type: application/json' --header 'Accept: text/plain' --header 'ClientAuth: cHl0aG9uOnRlc3Q=' --header 'Authorization: Basic dGVzdHBkcDphbHBoYTEyMw==' --header 'Environment: TEST' -d '{ "policyConfigType": "BRMS_PARAM", "policyName": "com.BRMSParamvFirewall", "policyDescription": "BRMS Param vFirewall policy", "policyScope": "com", "attributes": { "MATCHING": { "controller": "amsterdam" }, "RULE": { "templateName": "ClosedLoopControlName", "closedLoopControlName": "ControlLoop-vFirewall-d0a1dfc6-94f5-4fd4-a5b5-4630b438850a", "controlLoopYaml": "controlLoop%3A%0D%0A++version%3A+2.0.0%0D%0A++controlLoopName%3A+ControlLoop-vFirewall-d0a1dfc6-94f5-4fd4-a5b5-4630b438850a%0D%0A++trigger_policy%3A+unique-policy-id-1-modifyConfig%0D%0A++timeout%3A+1200%0D%0A++abatement%3A+false%0D%0A+%0D%0Apolicies%3A%0D%0A++-+id%3A+unique-policy-id-1-modifyConfig%0D%0A++++name%3A+modify+packet+gen+config%0D%0A++++description%3A%0D%0A++++actor%3A+APPC%0D%0A++++recipe%3A+ModifyConfig%0D%0A++++target%3A%0D%0A++++++%23+TBD+-+Cannot+be+known+until+instantiation+is+done%0D%0A++++++resourceID%3A+'${RESOURCE_ID}'%0D%0A++++++type%3A+VNF%0D%0A++++retry%3A+0%0D%0A++++timeout%3A+300%0D%0A++++success%3A+final_success%0D%0A++++failure%3A+final_failure%0D%0A++++failure_timeout%3A+final_failure_timeout%0D%0A++++failure_retries%3A+final_failure_retries%0D%0A++++failure_exception%3A+final_failure_exception%0D%0A++++failure_guard%3A+final_failure_guard" } } }' `https://localhost:8081/pdp/api/updatePolicy <https://localhost:8081/pdp/api/updatePolicy>`_


*(c) Push policy – this will trigger maven build on brmsgw*

::

        curl -v -k --silent -X PUT --header 'Content-Type: application/json' --header 'Accept: text/plain' --header 'ClientAuth: cHl0aG9uOnRlc3Q=' --header 'Authorization: Basic dGVzdHBkcDphbHBoYTEyMw==' --header 'Environment: TEST' -d '{ "pdpGroup": "default", "policyName": "com.BRMSParamvFirewall", "policyType": "BRMS\_Param" ' \ `https://localhost:8081/pdp/api/pushPolicy <https://localhost:8081/pdp/api/pushPolicy>`_ 

 

*(d) Restart PDP-D*

::

        [root@tomas-infra scripts]# kubectl exec -it onap-policy-drools-0 -n onap bash
        policy@onap-policy-drools-0:/tmp/policy-install$ source /opt/app/policy/etc/profile.d/env.sh && policy stop && sleep 1 && policy start
        [drools-pdp-controllers]
         L []: Stopping Policy Management... Policy Management (pid=3839) is stopping... Policy Management has stopped.
        [drools-pdp-controllers]
         L []: Policy Management (pid 12172) is running


At this step policy should be updated and drools rules for Firewall should be available/loaded into amsterdam controller,
which can be verified using:

::

        curl -k --silent --user 'demo@people.osaaf.org:demo123456!' -X GET `https://tomas-node0:30221/policy/pdp/engine/controllers/amsterdam/drools/facts/closedloop-amntrolloop.Params <https://tomas-node0:30221/policy/pdp/engine/controllers/amsterdam/drools/facts/closedloop-amntrolloop.Params>`_

Step 13. Mount APPC
===================

We can use following robot script for creating APPC mount:

::

        demo-k8s.sh <namespace> appc <module_name>
        - provide APPC with vFW module mount point for closedloop


Issue:

If public network used for Firewall VMs is not called *public*

e.g.

::

        openStackPublicNetId: "9403ceea-0738-4908-a826-316c8541e4bb“

        neutron net-list | grep 9403ceea-0738-4908-a826-316c8541e4bb
        neutron CLI is deprecated and will be removed in the future. Use openstack CLI instead.
        | 9403ceea-0738-4908-a826-316c8541e4bb | rc3-offline-network | b1ce7742d956463999923ceaed71786e | 1782c82c-cd92-4fb6-a292-5e396afe63ec 10.8.8.0/24 |

Robot script will fail on:

::

        [root@tomas-infra robot]# ./demo-k8s.sh onap appc vPKG-Module-1

        Number of parameters: 3
        KEY: appc
        ++ kubectl --namespace onap get pods
        ++ sed 's/ .\*//'
        ++ grep robot
        + POD=onap-robot-robot-5576c8f6cc-xfh9q
        + ETEHOME=/var/opt/OpenECOMP_ETE
        ++ kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-xfh9q -- bash -c 'ls -1q /share/logs/ | wc -l'
        
        export GLOBAL_BUILD_NUMBER=9
        
        + GLOBAL_BUILD_NUMBER=9
        ++ printf %04d 9
        
        + OUTPUT_FOLDER=0009_demo_appc
        
        + DISPLAY_NUM=99
        
        + VARIABLEFILES='-V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py'
        + kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-xfh9q -- /var/opt/OpenECOMP_ETE/runTags.sh -V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py -v MODULE_NAME:vPKG-Module-1 -d /share/logs/0009_demo_appc -i APPCMountPointDemo --display 99

        Starting Xvfb on display :99 with res 1280x1024x24
        Executing robot tests at log level TRACE
        ==============================================================================
        Testsuites
        ==============================================================================
        Testsuites.Demo :: Executes the VNF Orchestration Test cases including
        setu...
        ==============================================================================
        Create APPC Mount Point                                                      |
        FAIL                                                                         |

        {u'OS-EXT-STS:task_state': None, u'addresses': {u'demofwlsnk_unprotecteddemo': [{u'OS-EXT-IPS-MAC:mac_addr': u'fa:16:3e:04:42:b0', u'version': 4, u'addr': u'192.168.10.200', u'OS-EXT-IPS:type': u'fixed'}], u'rc3-offline-network': [{u'OS-EXT-IPS-MAC:mac_addr': u'fa:16:3e:9c:51:f7', u'version': 4, u'addr': u'10.8.8.26', u'OS-EXT-IPS:type': u'fixed'}], u'onap_private_vFWCL': [{u'OS-EXT-IPS-MAC:mac_addr': u'fa:16:3e:1d:27:e4', u'version': 4, u'addr': u'10.0.128.123', u'OS-EXT-IPS:type': u'fixed'}]}, u'links': [{u'href': u'http://10.20.30.40:8774/v2.1/b1ce7742d956463999923ceaed71786e/servers/d9d926ec-d14f-48f1-b473-35d43095b2e7', u'rel': u'self'}, {u'href': u'http://10.20.30.40:8774/b1ce7742d956463999923ceaed71786e/servers/d9d926ec-d14f-48f1-b473-35d43095b2e7', u'rel': u'bookmark'}], u'image': {u'id': u'fa1d0c4e-63f2-4458-b571-6c8fd17b917b', u'links': [{u'href': u'http://10.20.30.40:8774/b1ce7742d956463999923ceaed71786e/images/fa1d0c4e-63f2-4458-b571-6c8fd17b917b', u'rel': u'bookmark'}]}, u'OS-EXT-STS:vm\_state': u'active', u'OS-EXT-SRV-ATTR:instance\_name': u'demofwl01pgndemo-d9d926ec', u'OS-SRV-USG:launched\_at': u'2019-05-09T11:42:22.000000', u'flavor': {u'id': u'3', u'links': [{u'href': u'http://10.20.30.40:8774/b1ce7742d956463999923ceaed71786e/flavors/3', u'rel': u'bookmark'}]}, u'id': u'd9d926ec-d14f-48f1-b473-35d43095b2e7', u'security\_groups': [{u'name': u'onap\_sg'}, {u'name': u'default'}, {u'name': u'onap\_sg'}], u'user\_id': u'4fcfcc93d94d4534b71593fa3039801c', u'OS-DCF:diskConfig': u'MANUAL', u'accessIPv4': u'', u'accessIPv6': u'', u'progress': 0, u'OS-EXT-STS:power\_state': 1, u'OS-EXT-AZ:availability\_zone': u'nova', u'metadata': {u'vf\_module\_id': u'5c63abb2-83fa-4bf1-8264-44a36f12252a', u'vnf\_id': u'9a0d7dbb-f4a3-4f1f-a781-3b119722848f'}, u'status': u'ACTIVE', u'updated': u'2019-05-09T11:42:22Z', u'hostId': u'92f5e26cd9accaa41b8e491925f59537cc421acffe2da5ab298d0d4a', u'OS-EXT-SRV-ATTR:host': u'ONAP-3', u'OS-SRV-USG:terminated\_at': None, u'key\_name': u'vfw\_keydemo\_t2z5', u'OS-EXT-SRV-ATTR:hypervisor\_hostname': u'ONAP-3', u'name': u'demofwl01pgndemo', u'created': u'2019-05-09T11:42:07Z', u'tenant\_id': u'b1ce7742d956463999923ceaed71786e', u'os-extended-volumes:volumes\_attached': [], u'config\_drive': u''}/ public Not Found
        ------------------------------------------------------------------------------
        Testsuites.Demo :: Executes the VNF Orchestration Test cases inclu... | FAIL |
        1 critical test, 0 passed, 1 failed
        1 test total, 0 passed, 1 failed
        ==============================================================================
        Testsuites                                                            | FAIL |
        1 critical test, 0 passed, 1 failed
        1 test total, 0 passed, 1 failed
        ==============================================================================
        Output:  /share/logs/0009_demo_appc/output.xml
        Log:     /share/logs/0009_demo_appc/log.html
        Report:  /share/logs/0009_demo_appc/report.html

which can be patched in robot scripts

::

        root@tomas-infra robot]# kubectl  get pods -n onap | grep robot
        onap-robot-robot-5576c8f6cc-xfh9q                              1/1      
        Running      0          2d
        
        [root@tomas-infra robot]# kubectl cp -n onap onap-robot-robot-5576c8f6cc-xfh9q:/var/opt/OpenECOMP_ETE/robot/resources/demo_preload.robot ~/

                
        [root@tomas-infra robot]# vi ~/demo_preload.robot

        # change network_name from network_name=public to match your network name

        APPC Mount Point
            [Arguments]   ${vf_module_name}
            Run Openstack Auth Request    auth
            ${status}   ${stack_info}=   Run Keyword and Ignore Error    Wait or Stack to Be Deployed    auth    ${vf_module_name}   timeout=120s
            Run Keyword if   '${status}' == 'FAIL'   FAIL   ${vf_module_name} Stack is not found      
            ${stack_id}=    Get From Dictionary    ${stack_info}    id
            ${server_list}=    Get Openstack Servers    auth
            ${vpg_name_0}=    Get From Dictionary    ${stack_info}   vpg_name_0
            ${vnf_id}=    Get From Dictionary    ${stack_info}    vnf_id
            ${vpg_public_ip}=    Get Server Ip    ${server_list}   
            ${stack_info}   vpg_name_0    network_name=rc3-offline-network
            ${vpg_oam_ip}=    Get From Dictionary    ${stack_info}   vpg_private_ip_1
            #${appc}=    Create Mount Point In APPC    ${vpg_name_0}   ${vpg_oam_ip}
            #${appc}=    Create Mount Point In APPC    ${vnf_id}   ${vpg_oam_ip}
            ${appc}=    Create Mount Point In APPC    ${vnf_id}   ${vpg_public_ip}

::

[root@tomas-infra robot]# kubectl cp -n onap ~/demo_preload.robot onap-robot-robot-5576c8f6cc-xfh9q:/var/opt/OpenECOMP_ETE/robot/resources/demo_preload.robot

and rerun

::

        [root@tomas-infra robot]# ./demo-k8s.sh onap appc vPKG-Module-1
        Number of parameters: 3
        KEY: appc
        ++ kubectl --namespace onap get pods
        ++ sed 's/ .\*//'
        ++ grep robot
        + POD=onap-robot-robot-5576c8f6cc-rjbkf
        + ETEHOME=/var/opt/OpenECOMP_ETE
        ++ kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-rjbkf --
        bash -c 'ls -1q /share/logs/ | wc -l'
        + export GLOBAL_BUILD_NUMBER=19
        + GLOBAL_BUILD_NUMBER=19
        ++ printf %04d 19
        + OUTPUT_FOLDER=0019\_demo\_appc
        + DISPLAY_NUM=109
        + VARIABLEFILES='-V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py'
        + kubectl --namespace onap exec onap-robot-robot-5576c8f6cc-rjbkf -- /var/opt/OpenECOMP\_ETE/runTags.sh -V /share/config/vm_properties.py -V /share/config/integration_robot_properties.py -V /share/config/integration_preload_parameters.py -v MODULE\_NAME:vPKG-Module-1 -d /share/logs/0019_demo_appc -i
        APPCMountPointDemo --display 109
        Starting Xvfb on display :109 with res 1280x1024x24
        Executing robot tests at log level TRACE
        ==============================================================================
        Testsuites
        ==============================================================================
        Testsuites.Demo :: Executes the VNF Orchestration Test cases including
        setu...
        ==============================================================================
        Create APPC Mount Point                                               | PASS |
        ------------------------------------------------------------------------------
        Testsuites.Demo :: Executes the VNF Orchestration Test cases inclu... | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Testsuites                                                            | PASS |
        1 critical test, 1 passed, 0 failed
        1 test total, 1 passed, 0 failed
        ==============================================================================
        Output:  /share/logs/0019_demo_appc/output.xml
        Log:     /share/logs/0019_demo_appc/log.html
        Report:  /share/logs/0019_demo_appc/report.html
 


Step 14. Resolving potential problems
=====================================


**After this step CL should be visible in Darkstat on vSinc VM**

|image20|

 

**If something goes wrong following hints can be used for troubleshooting purposes:**
 

*(1) Check that VES events are coming from vFW VM to VesCollector*


::

        #VES Events
        curl -X GET -H 'Accept: application/json' -H 'Content-Type: application/cambria' `http://tomas-node0:30227/events/unauthenticated.VES_MEASUREMENT_OUTPUT/group1/C1 <http://tomas-node0:30227/events/unauthenticated.VES_MEASUREMENT_OUTPUT/group1/C1>`_

If the output is empty, one can verify DCAE IP from vFW VM

login to vfwsnk-1 and check

::

        root@vfwsnk-1:~# cat /opt/config/dcae_collector_ip.txt
        10.8.8.22


        root@vfwsnk-1:~# cat /opt/config/dcae_collector_port.txt
        30235

VES collector is by default listening on 8080:30235 port

::

        [root@tomas-infra robot]# kubectl get services -n onap | grep xdcae-ves-collector
        xdcae-ves-collector                NodePort       10.43.195.188  <none>       8080:30235/TCP         2d

So that combination of IP and port should be reachable from vFW VM

::

        ubuntu@vfwsnk-1:~$ telnet 10.8.8.22 30235
        Trying 10.8.8.22...
        Connected to 10.8.8.22.
        Escape character is '^]'.
        ^]

 
*2) Check if OnSet events are created by TCA analytics*

::

        # OnSet events from TCA to policy
        curl -i -X GET -H 'Accept: application/json' `http://tomas-node0:30227/events/unauthenticated.DCAE_CL_OUTPUT/group1/c1 <http://tomas-node0:30227/events/unauthenticated.DCAE_CL_OUTPUT/group1/c1>`_ 


if the list is empty, go to analytics pod and check tca logs

::

        [root@tomas-infra robot]# kubectl  exec -it dep-dcae-tca-analytics-68dcfcd767-wv97h -n onap bash
        root@dcae-tca-analytics:~# cat /opt/cdap/sdk/logs/cdap-debug.log

In our lab following problem was visible

::

        2019-05-09 15:13:54,858 - DEBUG [FlowletProcessDriver-TCAVESThresholdViolationCalculatorFlowlet-0-executor:o.o.d.a.a.c.s.p.AbstractMessageProcessor@157] - Processor: TCACEFPolicyEventNameFilter, Successful Completion Message: Policy Event Name and CEF Message Event Name match successful.Message EventName: vFirewallBroadcastPackets, Policy Event Names: vFirewallBroadcastPackets,vLoadBalancer,Measurement\_vGMUX, Incoming Message:  {"event":{"commonEventHeader":{"startEpochMicrosec":1557414790568806,"eventId":"TrafficStats\_1.2.3.4","nfcNamingCode":"vVNF","reportingEntityId":"No UUID available","internalHeaderFields":{"collectorTimeStamp":"Thu, 05 09 2019 03:13:17 UTC"},"eventType":"HTTP request rate","priority":"Normal","version":3,"reportingEntityName":"fwll","sequence":0,"domain":"measurementsForVfScaling","lastEpochMicrosec":1557414800780189,"eventName":"vFirewallBroadcastPackets","sourceName":"vFWSNK-1","nfNamingCode":"vVNF"},"measurementsForVfScalingFields":{"cpuUsageArray":[{"percentUsage":0,"cpuIdentifier":"cpu1","cpuIdle":100,"cpuUsageSystem":0,"cpuUsageUser":0}],"measurementInterval":10,"requestRate":6444,"vNicUsageArray":[{"transmittedOctetsDelta":0,"receivedTotalPacketsDelta":102,"vNicIdentifier":"eth0","valuesAreSuspect":"true","transmittedTotalPacketsDelta":0,"receivedOctetsDelta":4386}],"measurementsForVfScalingVersion":2}}}

 

Alarm is not triggered because there is mismatch in tca_policy settings

One can update the policy and replace vNicPerformanceArray with vNicUsageArray in CDAP gui.
Similar problem is documented in https://lists.onap.org/g/onap-discuss/topic/27329400

|image21|

Please note that one need to restart (stop/start) TCAVESCollectorFlow to propagate new tca_policy.

- Click on TCAVESAlertsTable
- Click on stopping TCAVESCollectorFlow
- Click on starting TCAVESCollectorFlow once again.

.. note:: we had to repeat this procedure couple of times (change tca_policy, restart flow) in order to get it working with new tca_policy. sometimes it resets back to default policy after 15 seconds for unknown reasons).

Effective policy should be printed after flow restart in cdap-debug.log

::

        root@dcae-tca-analytics:/opt/cdap/sdk/logs# tail -f cdap-debug.log  | grep Effective

Also DCAE_CL_OUTPUT topic should start having some records, which can be verified using

:: 

        [root@tomas-infra ~]#  curl -i -X GET -H 'Accept: application/json' http://tomas-node0:30227/events/unauthenticated.DCAE_CL_OUTPUT/group1/c1


**Further hints/notes (less frequently needed)**

 
In some deployments we had to change hostname of vFW VM, because it was putting hostname as UUID into VES events,
such hostname is was not matching with AAI database, which was fixed by changing hostname to VNF name we used for VFW VM.

::

        [root@tomas-infra robot]# ssh ubuntu@10.8.8.17 
        ubuntu@vfwsnk-1:~$ sudo su –
        root@vfwsnk-1:~# vi /etc/hostname

        # change to
        root@vfwsnk-1:~# cat /etc/hostname
        vFWSNK-1
        root@vfwsnk-1:~# reboot
        Broadcast message from ubuntu@vfwsnk-1
        (/dev/pts/0) at 15:17 ...

        The system is going down for reboot NOW!
        root@vfwsnk-1:~# Connection to 10.8.8.17 closed by remote host.

Check amsterdam controller for existence

::

        curl -k --silent --user 'demo@people.osaaf.org:demo123456!' -X GET `https://tomas-node0:30221/policy/pdp/engine/controllers/amsterdam/ <https://tomas-node0:30221/policy/pdp/engine/controllers/amsterdam/>`_


Check drools fact for amsterdam controller

::

        curl -k --silent --user 'demo@people.osaaf.org:demo123456!' -X GET `https://tomas-node0:30221/policy/pdp/engine/controllers/amsterdam/drools/ <https://tomas-node0:30221/policy/pdp/engine/controllers/amsterdam/drools/>`_

Check for available topics in DMAAP

::

        curl -i -X GET -H 'Accept: application/json' http://tomas-node0:30227/topics

        {"topics": [
            "ECOMP-PORTAL-OUTBOX-APP1",
            "__consumer_offsets",
            "POA-AUDIT-RESULT",
            "ECOMP-PORTAL-OUTBOX-POL1",
            "SDC-DISTR-STATUS-TOPIC-AUTO",
            "unauthenticated.SEC_HEARTBEAT_OUTPUT",
            "APPC-CL",
            "PDPD-CONFIGURATION",
            "POLICY-CL-MGT",
            "SDC-DISTR-NOTIF-TOPIC-AUTO",
            "APPC-LCM-READ",
            "unauthenticated.DCAE_CL_OUTPUT",
            "POA-RULE-VALIDATION",
            "AAI-EVENT",
            "unauthenticated.VES_MEASUREMENT_OUTPUT",
            "ECOMP-PORTAL-OUTBOX-VID1",
            "ECOMP-PORTAL-INBOX",
            "ECOMP-PORTAL-OUTBOX-SDC1",
            "org.onap.dmaap.mr.PNF_READY",
            "org.onap.dmaap.mr.PNF_REGISTRATION",
            "APPC-TEST1",
            "POA-AUDIT-INIT",
            "ECOMP-PORTAL-OUTBOX-DBC1"
        }


Check for available VNFs in AAI

::

        curl -i -X GET --user aai@aai.onap.org:demo123456! -H 'Accept:application/json' -H 'Content-Type: application/json' -H 'X-FromAppId:MSO' -H 'X-TransactionId:73498' https://tomas-node0:30233/aai/v14/network/generic-vnfs/ --insecure


Check for demo service instances in AAI

::

        curl -i -X GET --user aai@aai.onap.org:demo123456! -H 'Accept:application/json' -H 'Content-Type: application/json' -H 'X-FromAppId:MSO' -H 'X-TransactionId: 89273498' https://tomas-node0:30233/aai/v14/business/customers/customer/Demonstration/service-subscriptions/service-subscription/vFWCL/service-instances/service-instance --insecure

Check APPC for currently active PG streams

::

        # VNF ID of vPKG-1 VF is used in node index
        curl -i -X GET --user appc@appc.onap.org:demo123456! http://tomas-node0:30230/restconf/config/network-topology:network-topology/topology/topology-netconf/node/f611b9d5-8715-4963-baba-e9c06e1a80cb/yang-ext:mount/sample-plugin:sample-plugin/pg-streams

 

.. |image0| image:: images/image002.jpg
   :width: 387px
   :height: 393px
.. |image1| image:: images/image004.jpg
   :width: 390px
   :height: 457px
.. |image2| image:: images/image006.jpg
   :width: 605px
   :height: 195px
.. |image3| image:: images/image008.jpg
   :width: 358px
   :height: 376px
.. |image4| image:: images/image010.jpg
   :width: 443px
   :height: 388px
.. |image5| image:: images/image012.jpg
   :width: 606px
   :height: 222px
.. |image6| image:: images/image014.jpg
   :width: 605px
   :height: 169px
.. |image7| image:: images/image016.jpg
   :width: 604px
   :height: 222px
.. |image8| image:: images/image018.jpg
   :width: 381px
   :height: 221px
.. |image9| image:: images/image020.jpg
   :width: 470px
   :height: 414px
.. |image10| image:: images/image022.jpg
   :width: 605px
   :height: 218px
.. |image11| image:: images/image024.jpg
   :width: 289px
   :height: 375px
.. |image12| image:: images/image026.jpg
   :width: 322px
   :height: 285px
.. |image13| image:: images/image028.jpg
   :width: 267px
   :height: 358px
.. |image14| image:: images/image030.jpg
   :width: 359px
   :height: 318px
.. |image15| image:: images/image032.jpg
   :width: 302px
   :height: 338px
.. |image16| image:: images/image034.jpg
   :width: 298px
   :height: 336px
.. |image17| image:: images/image036.jpg
   :width: 604px
   :height: 221px
.. |image18| image:: images/image038.gif
   :width: 548px
   :height: 266px
.. |image19| image:: images/image040.gif
   :width: 602px
   :height: 182px
.. |image20| image:: images/image042.jpg
   :width: 154px
   :height: 161px
.. |image21| image:: images/image044.jpg
   :width: 605px
   :height: 246px
