# Design

The templates and scripts in this repository are a deployment method for Palo Alto Networks Reference Architectures. You can find details on each of the design models, and step-by-step instructions for deployment at https://www.paloaltonetworks.com/referencearchitectures 

This repository currently covers the AWS, Azure, and GCP Reference Architectures.

# Prerequisites

The templates and scripts in this repository are designed to be used with PanHandler. For details on how to get PanHandler running, see: https://panhandler.readthedocs.io/en/master/running.html

# Usage

1. Login to Panhandler and navigate to **Panhandler > Import Skillet Repository**.
2. In the **Repository Name** box, enter **Reference Architecture Automation**.
3. In the **Git Repository HTTPS URL** box, enter **https://github.com/PaloAltoNetworks/reference_architecture_automation.git**, and then click **Submit**.

Next, you need to create an environment that stores your authentication information. 

## If you are deploying to Azure

4. At the top right of the page, click the lock icon.
5. In the **Master Passphrase** box, enter a passphrase, and then click **Submit**.
6. Navigate to **PalAlto > Create Environment**.
7. In the **Name** box, enter **Azure**.
8. In the **Description** box, enter **Azure Environment**, and then click **Submit**.

Next, identify the Azure subscription to use.

9. In the **Key** box, enter **SUBSCRIPTION**.
10. In the **Value** box, enter your Azure subscription.

Next, enter a password for the deployment to assign the admin user.

11. In the **Key** box, enter **PASSWORD**.
12. In the **Value** box, enter the password you want Panorama and the VM-Series admin user to have.

Optionally, enter a prefix to be used in the deployment. Prefixing a name to the deployment helps avoid problems. Many resources require a unique name. 

13. In the **Key** box, enter **DEPLOYMENT_NAME**.
14. In the **Value** box, enter the name to prefix to the resources.
15. Click **Load**.

Next, deploy Panorama.

16. Navigate to **PanHandler > Skillet Collections > Azure Reference Architecture Skillet Modules > 1 - Azure Login (Pre-Deployment Step) > Go**.

17. After each module is complete, deploy the next module in the list. 

## If you are deploying to AWS

4. At the top right of the page, click the lock icon.
5. In the **Master Passphrase** box, enter a passphrase, and then click **Submit**.
6. Navigate to **PalAlto > Create Environment**.
7. In the **Name** box, enter **AWS**.
8. In the **Description** box, enter **AWS Environment**, and then click **Submit**.

Next, create the authentication key pairs.

9. In the **Key** box, enter **AWS_ACCESS_KEY_ID**.
10. In the **Value** box, enter your AWS access key.
11. In the **Key** box, enter **AWS_SECRET_ACCESS_KEY**.
12. In the **Value** box, enter your AWS secret.

Next, enter a password for the deployment to assign the admin user.

13. In the **Key** box, enter **PASSWORD**.
14. In the **Value** box, enter the password you want Panorama and the VM-Series admin user to have.
15. Click **Load**.

Next, deploy Panorama.

16. Navigate to **PanHandler > Skillet Collections > AWS Reference Architecture Skillet Modules > 1 - Deploy Panorama > Go**.

After each module is complete, deploy the next module in the list. 

## If you are deploying to GCP

GCP IAM permissions are challenging to get correct when using a service account with terraform. Follow the guidance in https://github.com/terraform-google-modules/terraform-google-project-factory to create a seed service account to use with these skillets.

4. At the top right of the page, click the lock icon.
5. In the **Master Passphrase** box, enter a passphrase, and then click **Submit**.
6. Navigate to **PalAlto > Create Environment**.
7. In the **Name** box, enter **GCP**.
8. In the **Description** box, enter **GCP Environment**, and then click **Submit**.

Next, enter your Google credentials and organization information.

9. In the **Key** box, enter **GOOGLE_CREDENTIALS**.
10. In the **Value** box, enter the json credentials generated when you set up the seed service account.
11. In the **Key** box, enter **FOLDER**.
12. In the **Value** box, enter the id for the folder the projects should be created in.
13. In the **Key** box, enter **BILLING_ACCOUNT**.
14. In the **Value** box, enter the billing account id to use when creating the projects.

Next, enter a password for the deployment to assign the admin user.

15. In the **Key** box, enter **PASSWORD**.
16. In the **Value** box, enter the password you want Panorama and the VM-Series admin user to have.
17. Click **Load**.

Next, deploy Panorama.

18. Navigate to **PanHandler > Skillet Collections > GCP Reference Architecture Skillet Modules > 1 - Deploy Panorama > Go**.

After each module is complete, deploy the next module in the list. 

# Support

This template/solution is released under an as-is, best effort, support policy. These scripts should be seen as community supported and Palo Alto Networks will contribute our expertise as and when possible. We do not provide technical support or help in using or troubleshooting the components of the project through our normal support options such as Palo Alto Networks support teams, or ASC (Authorized Support Centers) partners and backline support options. The underlying product used (the VM-Series firewall) by the scripts or templates are still supported, but the support is only for the product functionality and not for help in deploying or using the template or script itself. Unless explicitly tagged, all projects or work posted in our GitHub repository (at https://github.com/PaloAltoNetworks) or sites other than our official Downloads page on https://support.paloaltonetworks.com are provided under the best effort policy.

For assistance from the community, please post your questions and comments either to the GitHub page where the solution is posted or on our Live Community site dedicated to public cloud discussions at https://live.paloaltonetworks.com/t5/AWS-Azure-Discussions/bd-p/AWS_Azure_Discussions
