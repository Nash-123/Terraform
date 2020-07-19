provider "aws" {
  region  = "ap-south-1"
  profile = "nishan"
}

#creating the security group

resource "aws_security_group" "allow_http1" {
  name        = "allow_http1"
  description = "security groups have been allocated!!"

  ingress {
    description = "ssh server access by any client"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "http website access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "nfs access"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_http1"
  }

}

# lauching instance

resource "aws_instance" "web1" {
 ami = "ami-0447a12f28fddb066"
 instance_type = "t2.micro"
 key_name = "mykey111222"
 security_groups = [ "allow_http" ]
  
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/mamab/Downloads/mykey111222.pem")
    host     = aws_instance.web1.public_ip
  } 

 tags = {
  Name = "TerraForm Server initialized by nishan"
 }
provisioner "remote-exec" {
connection {
    type     = "ssh"
    user     = "ec2-user"
    port     =  22
    private_key = file("C:/Users/mamab/Downloads/mykey111222.pem")
    host     = aws_instance.web1.public_ip
  }
    inline = [
      "sudo yum install httpd git amazon-efs-utils nfs-utils php -y ", 
      "sudo systemctl restart httpd", 
      "sudo systemctl enable httpd",
      ]
}
}

# creation of EFS

resource "aws_efs_file_system" "foo" {
  creation_token = "my-product1"
    tags = {
    Name = "EFSforNishan"
    
  }
}
resource "aws_efs_mount_target" "alpha" {
  depends_on =  [ aws_efs_file_system.efs1,]
  file_system_id = aws_efs_file_system.efs1.id
  subnet_id      = aws_instance.web1.subnet_id
  security_groups = ["allow_http"]
}


resource "null_resource" "nullremotenishan"  {
  depends_on = [aws_efs_mount_target.alpha,]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    port     =  22
    private_key = file("C:/Users/mamab/Downloads/mykey111222.pem") 
    host     = aws_instance.web1.public_ip
  }



provisioner "remote-exec" {
  inline = [
      "sudo mount -t nfs4 ${aws_efs_mount_target.alpha.ip_address}:/ /var/www/html/",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Nash-123/Terraform.git  /var/www/html/"
  ]
}
}


#creation of s3 bucket

resource "aws_s3_bucket" "bucketnishan" {
  bucket = "nishanterabucket"
  acl = "private"
  region = "ap-south-1"
}

resource "aws_s3_bucket_object" "object" {
 bucket = "nishanterabucket"
 key = "image.jpg"
 source = "image.jpg"
}
locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_s3_bucket_policy" "policybucketnishan" {
   depends_on = [
            aws_cloudfront_distribution.s3_distribution,
          ]

  bucket = aws_s3_bucket.bucketnishan.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

#creation of cloud front
resource "aws_cloudfront_origin_access_identity" "origin_access" {
      comment = "OAI"
     }
resource "aws_cloudfront_distribution" "s3_distribution" {

          depends_on = [
            aws_s3_bucket_object.object,
          ]


        origin {
           domain_name = aws_s3_bucket.bucketnishan.bucket_regional_domain_name
           origin_id   = local.s3_origin_id
           s3_origin_config {
               origin_access = aws_cloudfront_origin_access_identity.origin_access.cloudfront_access_identity_path
              }
     }
  enabled             = true
  is_ipv6_enabled     = true
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    forwarded_values {
           query_string = false
    cookies {
         forward = "none"
        }
      }
   viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 3600
      max_ttl                = 86400
   }
 restrictions {
     geo_restriction {
       restriction_type = "none"
      }
  }
 viewer_certificate {
     cloudfront_default_certificate = true
   }
 }
 data "aws_iam_policy_document" "s3_policy" {
    statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucketnishan.arn}/*"]
principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access.iam_arn}"]
    }
  }
statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.bucketnishan.arn}"]
principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access.iam_arn}"]
    }
  }
}



