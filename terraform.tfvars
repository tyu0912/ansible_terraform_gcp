project = "ansible-terraform-282015"
credentials_file = "ansible-terraform-282015-f4561a76bd8d.json"
cidrs = [ "10.0.0.0/16", "10.1.0.0/16" ]
region = "us-west1"

machine_types = {
  dev  = "f1-micro"
  test = "n1-highcpu-32"
  prod = "n1-highcpu-32"
}
