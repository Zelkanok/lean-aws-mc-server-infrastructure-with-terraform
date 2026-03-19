# lean-aws-mc-server-infrastructure-with-terraform WIP

Leverage Terraform and AWS to construct an on-demand Minecraft server instance for playing with friends!
Easy set up for both vanilla and modded servers (hopefully). Also quick & dirty introductory guide for using Terraform and AWS to create something tangible (also hopefully)!
The source code is really downright simple, but the most important thing is this README.md that contains helpful instructions and links for others to learn and explore. 

# TODO:

1. Create example user_data scripts for setting up different servers:
    - vanilla
    - fabric
    - forge
    - etc.
2. Clean up the README.md to provide a better experience for beginners and everyone.
3. Learn and implement better practices within the Terraform code and AWS infrastructure.

# Introduction:

## Reasons for hosting your server with AWS:

- If you're considering a modded server, MC Realms will obviously not support it. Only vanilla worlds are possible with Realms.
- Hosting on a local machine (i.e. your personal PC), while possibly cheaper, requires dedicating hardware to run the server while exposing your own network to security risks. If you are planning to set up a modded MC server, then you will need a good amount of memory and cpu power dedicated to running anything like the Distant Horizons mod. There is also the requirement of knowing how to configure your own infrastructure to support the server. Granted, learning AWS and Terraform is essentially the same steps as setting it up on your personal network, but with the added benefit of security and borrowing expensive hardware through the cloud.
- Using a hosting service is also relatively overkill for a server with just a couple of friends. Overhead costs can be avoided with AWS, where you can terminate infrastructure while preserving your backups and server data on an S3 or local storage for the next time you want to play. That means you decide when to run the server, only incurring costs on resources at your choosing.

__In summary, this repo and guide is for people who want to try hosting a server via the cloud while also learning a little bit about AWS and Terraform. Full control over server setup, pay-as-you-go pricing on resources, cloud security, and an introduction to tools used in industry.__

AWS actually has a blog post on how to set up a vanilla minecraft server, written by Mitul Granger and Caleb Grode. It's a great starting point for anyone who just wants to deploy a personal minecraft server via the AWS management console. (https://aws.amazon.com/blogs/gametech/setting-up-a-minecraft-java-server-on-amazon-ec2/)

The only issue is that the guide requires you to set up everything manually through the AWS management console. The guide doesn't offer the additional features of connecting a general S3 bucket for server files, or tearing down peripheral infrastructure to minimize costs. It also doesn't mention things like security groups, policies, and roles. With Terraform, we can do all of the detail work with only a few simple commands from the terminal. This guide also includes a couple more comprehensive steps on how to properly set up your AWS account and articles on why certain things are done (for peace of mind).

**_(Still give the guide blog a try! It's a great exercise to get familiar with the AWS console and other concepts later in this guide!)_**

## Why Terraform?

Terraform is a great way to automate, provision, and manage infrastructure (cloud and on-premise) using code rather than manual processes. It allows you to define infrastructure as code (IaC), ensuring consistent, reusable, and version-controlled environments across multiple platforms like AWS, which improves speed, reduces errors, and prevents configuration drift. All of this is to say that you can set up instances and server configurations and also ensure all related resources are also teminated upon destruction when you want to shut down the server. That way you don't have some sneaky-beaky leftover stuff that could be costing you money.

AWS also has their own IaC known as CloudFormation. But, ironically, everyone in industry prefers Terraform. Even more ironically, most developers will defer to using the terraform-aws-modules collection that is maintained by the community. (https://registry.terraform.io/namespaces/terraform-aws-modules) (https://github.com/terraform-aws-modules)

If you want to get started with some simple tutorials on Terraform, visit https://developer.hashicorp.com/terraform/tutorials and check out their AWS tutorials.

# Instructions

If you don't really care for the "how" & "why", or you have some adequate level of technical knowledge, just follow the steps below.

For more in depth instructions, follow the attached links for each step to learn more. (I'll eventually flesh out the rest of the guide in the future)

Getting frustrated and stuck is a normal part of learning! You can do it! I believe in you! Google is your friend! (But, not the AI Overview! always check out primary sources first!)

## Requirements:

1. If you found this repo, I'm assuming you have a git account.
    - If not, set up a github account (https://docs.github.com/en/get-started/start-your-journey/creating-an-account-on-github).
    - Then, set up git on your computer (https://docs.github.com/en/get-started/git-basics/set-up-git). Either CLI or the desktop app is fine.
1. Create an AWS account. 
    - All you need is the free-tier: https://aws.amazon.com/free/
    - Set up a admin-user account as proxy to protect your root account. You can read about the reasoning and steps in the related link: (https://docs.aws.amazon.com/streams/latest/dev/setting-up.html)
    - Generate access keys on your account for AWS CLI configuration later.
4. Set up the AWS CLI and configure your access keys
    - (https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)
    - (https://docs.aws.amazon.com/streams/latest/dev/setup-awscli.html)
5. Set up the Terraform CLI (https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
6. I use VSCode to edit and manage my project files (personal preference), you can use whichever code editor you are comfortable with.
    - https://code.visualstudio.com/download
    - Install whichever Terraform extensions you want to help with IntelliSense (https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform)

## Setup (WIP):

1. Git clone this repo.
    - https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository
    - git@github.com:andrewenletoh/lean-aws-mc-server-infrastructure-with-terraform.git
2. Open the project folder in the code edit of your choice.
3. Open the "main.tf" file and read through the comments.
    - The comments will provide explanations for modules and their functions (for the beginners)
    - The comments will also indicate where to populate and/or replace your own data.
    - Everything is written in modules, as explained above (https://github.com/terraform-aws-modules). It's just easier.
4. Create a general S3 bucket to hold your server files (world data backup, modpacks, etc.) (https://docs.aws.amazon.com/AmazonS3/latest/userguide/GetStartedWithS3.html#creating-bucket)
    - OR, you can uncomment the `"s3_bucket"` module to let Terraform set it up for you.
    - __WARNING: If you decide to let Terraform generate the s3_bucket for you, it will also attempt to wipe it upon `terraform destroy`. Luckily, if you have files uploaded to the s3, the `destroy` command will throw an error__
3. In your terminal, run `terraform init` and `terraform apply`.
    - Also input `yes` when prompted during the `terraform apply` command runtime.
4. Double check infrastructure on aws console and check everything is set up correctly.
5. Instance/SSH connect into EC2 instance to set up the last details of the server.
    - This will depend on how you want to set up your server, whether it is moving `server.properties` file and modpacks between your ec2 and s3 for editing, kicking off the server.jar to launch your server
    - You can also edit the user_data script in "main.tf" to do all the initial setup for you via a bash script.
    - Eventually, we will provide a guide on that in the future, but you can just look up guides on how to set up servers on your local machines, and then apply the same steps either through the EC2 instance terminal or automate it with the user_data script.

# FAQ

### Q: Can you explain more about a certain step?
A: Yes, just head on over to the "Discussions" tab. If you have a question, someone else probably had the same one, so be sure to look through and see if your issue or question has already been addressed. Other people can jump in and help too!

### Q: Isn't there a better way to do a certain task?
A: Probably, haha. I threw this repo together from my own learnings while setting up a server for friends. It is definitely not the end-all be-all, so I appreciate any suggestions or ideas.

### Q: Can I contribute to this project?
A: Sure! As long as it's a meaningful addition that won't clutter the project any more than it already is.

### Q: Why do you have everything in a single main.tf? Also, your variables.tf and outputs.tf are empty.
A: The infrastructure is not really complex, so I saw no need to really try any harder on fleshing out the rest. Currently, the project is pretty simple and straightforward.

### Q: Can I use your code and work in my own project?
A: That is the aim! Please use this project as a template to go create your own unique stuff! None of the actual code is complex. The biggest thing is the README.md that contains helpful instructions and links for others to learn and explore. All I ask is that you give back to the community and provide your work as open-source for further improving tools for everyone.