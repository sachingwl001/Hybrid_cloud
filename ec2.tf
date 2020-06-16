provider "aws" {
  region  = "ap-south-1"
  profile = "sachin" 
}


resource "aws_security_group" "RULE" {
	name = "allow_httpd"

	ingress {

		from_port  = 80
		to_port    = 80
		protocol   = "tcp"
		cidr_blocks = ["0.0.0.0/0"]

		
	}
	
	ingress {
		
		from_port  = 22
		to_port    = 22
		protocol   = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	egress {
		from_port  = 0
		to_port    = 0
		protocol   = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
	
	tags = {
	Name = "allow_httpd"
	}
}

resource "aws_instance" "first" {

   depends_on = [
		aws_security_group.RULE,
                                     ]

  ami           = "ami-00ca32b3b3324cc1a"
  instance_type = "t2.micro"
  key_name = "task_key"
  security_groups = ["allow_httpd"]
  
   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ASUS/Downloads/task_key.pem")
    host     = aws_instance.first.public_ip
  }

   provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  } 


  tags = {
    Name = "firstos"
  }
}




resource "aws_ebs_volume" "ebs_volume_create" {
  availability_zone = aws_instance.first.availability_zone
  size              = 1
  tags = {
    Name = "task1_ebs"
  }
}

resource "aws_volume_attachment" "ebs_volume_attach" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ebs_volume_create.id}"
  instance_id = "${aws_instance.first.id}"
  force_detach = true
}

output "IP_OF_FIRST"{
   value = aws_instance.first.public_ip
}

resource "null_resource" "null_remote_access" {

  depends_on = [
    aws_volume_attachment.ebs_volume_attach,
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/ASUS/Downloads/task_key.pem")
    host     = aws_instance.first.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/sachingwl001/Hybrid_cloud.git /var/www/html/"
    ]
  }
}

resource "aws_s3_bucket" "bucket_create" {
                depends_on=[
                                  null_resource.null_remote_access
                                     ]
                bucket = "59641n"
                acl = "public-read"

 }

resource  "aws_s3_bucket_object" "bucket_deployer"{
               bucket = "59641n"
               key = "terraform.jpg"
               source =  "C:/Users/ASUS/Desktop/terraform.jpg "
               acl =  "public-read"
               content_type= "image/jpg"
               depends_on= [
                                aws_s3_bucket.bucket_create
]
}

variable "var1" {
	default = "s3-"
}

locals {
s3_origin_id = "${var.var1}${aws_s3_bucket.bucket_create.id}"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
	origin {
	domain_name = "${aws_s3_bucket.bucket_create.bucket_regional_domain_name}"
	origin_id   = "${local.s3_origin_id}"
	}

  	enabled             = true
  	is_ipv6_enabled     = true
  	comment             = "Some comment"
  
	default_cache_behavior {
    		allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    		cached_methods   = ["GET", "HEAD"]
    		target_origin_id = "${local.s3_origin_id}"

    		forwarded_values {
      			query_string = false

	      		cookies {
        			forward = "none"
      			}
    		}

    	viewer_protocol_policy = "allow-all"
    
 	}
	
	restrictions {
    		geo_restriction {
      			restriction_type = "none"
    		}
  	}

	viewer_certificate {
    		cloudfront_default_certificate = true
  	}

	depends_on=[
		aws_s3_bucket_object.bucket_deployer
	]

	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = file("C:/Users/ASUS/Downloads/task_key.pem")
		host = aws_instance.first.public_ip
	}
	provisioner "remote-exec" {
		inline = [
				"sudo su << EOF",
            					"echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.bucket_deployer.key}'>\" >> /var/www/html/task1.html",
           					"EOF"
			]
	}
	


}
resource "null_resource" "nulllocal1" {

	depends_on = [
		aws_cloudfront_distribution.s3_distribution
	]

	provisioner "local-exec" {
		command = "chrome  ${aws_instance.first.public_ip}"
	}
}








