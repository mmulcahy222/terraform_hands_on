It was a pure joy to do a HANDS ON practical project & to grind & struggle the hard way, from the ground up, to make some architectures.

I did three terraform files which I have put in this REPO, related to Cloud Networking. 2 on Amazon Cloud, 1 on Microsoft Azure.

1. I used Transit Gateway in AWS to connect two VPC's together. I could have used a VPN to connect to it if I wanted to, but all I really did was SSH into one of the VPC's (spokes) and it connected to the other one by going through the transit gateway. Be sure to check the full config in the links on top of the page.

![](images/terraform_1_pings.png)
![](images/terraform_1_iaas.png)

2. I come from a strong Amazon AWS Background, but I discovered that Microsoft Azure has actually more job openings and is gaining market share. I did hands on work on Microsoft Azure, Terraform & Cloud Networking on a practical hands-on basis. Thing is, there is no native Transit Gateway in Microsoft Azure. This made it that much more challenging. But in turn, more rewarding. They would be using Virtual Network Gateways, which doubles as a VPN endpoint & VPN capable device if you desire it so. VNet Peerings are required here for Azure, and be sure that the peerings are on BOTH sides for the Virtual Network Gateway to work. Be sure to check the full config in the links on top of the page.

![](images/terraform_2_pings.png)
![](images/terraform_2_iaas.png)

3. Amazon AWS Lattice. At first it was very very hard. I'm like how the hell is it simplifying ANYTHING when I have to go through this rigamarole & come across new constructs I've never seen. But having worked with it HANDS ON with my hands dirty in the trenches for days, I ... GET IT. I really .... GET IT. What it does? It decouples the implementation of various computing styles of many levels into one API at the listener rule & the listener path & public DNS that can be CNAMEd into a neater URI/URL. I made the default VPC the client VPC that will be associated with the service network, which I learned is not even a VPC itself! The service network connects with a Lambda, and another VPC that holds EC2. Of course, it can have EKS/ELB, but this was a Lattice project!

![](images/terraform_3_pings.png)
![](images/terraform_3_pings_2.png)
![](images/terraform_3_iaas.png)
