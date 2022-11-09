# CloudFront Terraform Module

This Terraform module provides a standard CloudFront configuration. The approach here allows three levels of configuration (each subsequent level taking precedence) as follows:
1. "Organisation" level :- these are set in the module here (in the `locals { defaults = {...` block) and apply to all distributions.
2. "Environmental" level :- these are set in the relevant TF module and are passed through as `var.defaults...`. These supersede anything from **1.**
3. "Distribution" level :- these are also set in the TF code and are passed through as `var.args...`. These supersede anything from **2.** or **1.**

The principle here is to reduce duplication. Each `module` using this source should only need to specify the arguments that are unique to that distribution. Common arguments (perhaps `default_cache_behavior` or common `custom_header`s) can be set at level 2 and can be applied to all distributions within that 'environment'.  
An example of parameter setting / precedence is illustrated in [the table below](#example-of-parameter-hierarchy-and-precedence).


## Deploying a New CloudFront Distribution
The most basic level of Module specification would be something like:
```terraform
module "example" {
  source = "github.com/uktrade/terraform-module-cloudfront/cloudfront"
  args = {
    aliases = ["my-alias"]
    origin = [
      {
        domain_name = "my-origin-domain-name"
        custom_origin_config = [{ enabled = true }]
      },
    ]
  }
}
```
This would deploy a simple CloudFront distribution with a custom origin.  
**Note** that some origin config is always required. If you want a custom origin with all the defaults, provide any parameter (so the custom_origin_config list is not empty). It doesn't need to be one of the recognised parameters for this block. Since if it's some `foo=bar` type parameter, it won't be read or used in any config. The example above shows `[{ enabled = true }]` which achieves the same.

The above could be further enhanced by adding `defaults = ...` as follows...
```terraform
module "example" {
  source = "...
  defaults = local.defaults
  ...
}
```
...which would allow the application of "Environmental" defaults (level 2).  
(`local.defaults` will have been defined elsewhere in the TF file)

## Importing an Existing CloudFront Distribution
To import existing distributions into Terraform using this module, this approach is recommended:

1. Capture the existing configuration before starting (and any other pre-import info such as output from a curl, etc.). The following command will do this:
   - `aws cloudfront get-distribution --id <<id>> > <<id>>-BEFORE.json`
2. Create a module.
   - Ensure the module name is unique.
   - Can use the basic example above for this (and pass in any `defaults` as required).
3. Run a `terraform init` to add the new module
4. Run a `terraform plan`
   - You should hopefully see a message such as `Plan: 1 to add, 0 to change, 0 to destroy.` (unless anything else was added - certificates, etc.)
   - **Don't apply this - you need to import first!**
5. Import the resource with a "[terraform import ADDRESS ID](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#import)" command.
   - You can get the import address from the "plan" stage (the "...will be created" output)
   - The ID will be the one from step 1.

Import example:
```
$ terraform import module.<<module_name>>.aws_cloudfront_distribution.standard E74FTE3EXAMPLE

module.<<module_name>>.aws_cloudfront_distribution.standard: Importing from ID "E74FTE3EXAMPLE"...
module.<<module_name>>.aws_cloudfront_distribution.standard: Import prepared!
  Prepared aws_cloudfront_distribution for import
module.<<module_name>>.aws_cloudfront_distribution.standard: Refreshing state... [id=E74FTE3EXAMPLE]
Import successful!
The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.
```
6. Run another `terraform plan`.
   - This time you should see..... `Plan: 0 to add, 1 to change, 0 to destroy`.
   - The key is that *1 to add* is now *1 to change*.
7. So now you need to update the config you're passing in so it matches the existing distribution - either shows no changes, or just changes you were expecting.
   - You can use the "`...before.json`" from step 1 for this - or the plan output (what it would change / remove if applied as is).
   - The plan output is usually a better option since this shows the arguments with 'Terraform labels' (such as `custom_origin_config`) rather than AWS API labels (where it will be `CustomOriginConfig`).
8. Repeat steps 6. and 7. as required until the plan output is as required. Potentially no changes (though there are usually tag changes).
   - If you see `No changes. Your infrastructure matches the configuration.` - you're done.  
   - At the very least, you'll probably see tagging changes.  

9.  Then run `terraform apply` to apply any updates / refresh the Terraform state with the new distribution.
10.  Optional: you may also want to re-run the `aws cloudfront get-distribution...` command - to compare before / after configuration is as expected.

## Example of Parameter Hierarchy and Precedence
The table below illustrates how arguments at the 3 levels are applied.  
- Here, arguments such as `default_cache_behavior.allowed_methods` have been set at the Environment level (2) - to override the Organisation level (1) - but then do not need setting for each Distribution (3).
- Whereas arguments such as `cached_methods` can be ignored at levels 2 and 3, if the Organisation level (1) is appropriate.  
- Only arguments that are applicable to this specific distribution (e.g. Origin, Alias and Certificate here) are set at the Distribution level.

Note that in this example, `minimum_protocol_version` is set at the Environment level - just to illustrate how duplication can be avoided. It would not need specifying in any distribution.

| 1. <font color="red">Organisation Defaults</font> | 2. <font color="cyan">Environment Defaults</font> | 3. <font color="yellow">Distribution Args</font> | **Result** |
| - | - | - | - |
| *...many...*<br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br> | default_cache_behavior = {<br>allowed_methods  = ["GET", "HEAD", "DELETE", "POST"]<br>viewer_protocol_policy = "redirect-to-https"<br>}<br>logging_config = [{<br>bucket = "my-log-bucket.s3.amazonaws.com"<br>}]<br>viewer_certificate = {<br>minimum_protocol_version = "TLSv1.2_2021"<br>}<br><br><br><br><br><br><br><br> | aliases = ["my-alias..."]<br>viewer_certificate = {<br>acm_certificate_arn = "arn:aws:acm:..."<br>}<br>origin = [<br>{<br>domain_name = "origin-1..."<br>custom_origin_config = [{ enabled = true }]<br>},<br>{<br>domain_name = "origin-2..."<br>custom_origin_config = [{ enabled = true }]<br>}<br>]<br>viewer_certificate = {<br>acm_certificate_arn = "arn:aws:acm:us-east-1:....."<br>ssl_support_method = "sni-only"<br>}<br> |  |
| <font color="red">DistributionConfig: {<br>Aliases: {<br>Quantity: 0<br>},<br><br><br><br>Origins: {<br>Quantity: 0,<br>Items: [<br>]<br>},<br><br><br><br><br><br><br>DefaultCacheBehavior: {<br>ViewerProtocolPolicy: "allow-all",<br>AllowedMethods: {<br>Quantity: 2,<br>Items: [<br>HEAD,<br>GET<br><br><br>],<br>CachedMethods: {<br>Quantity: 2,<br>Items: [<br>HEAD,<br>GET<br>]<br>}<br>},<br>},<br>Logging: {<br>Enabled: false,<br>IncludeCookies: false,<br>Bucket: "",<br>Prefix: ""<br>},<br>PriceClass: "PriceClass_All",<br>ViewerCertificate: {<br>CloudFrontDefaultCertificate: true,<br><br>SSLSupportMethod: "vip",<br>MinimumProtocolVersion: "TLSv1",<br><br>CertificateSource: "cloudfront"<br>},</font> | <font color="cyan"><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br>DefaultCacheBehavior: {<br>ViewerProtocolPolicy: "redirect-to-https",<br>AllowedMethods: {<br>Quantity: 4,<br>Items: [<br>HEAD,<br>DELETE,<br>POST,<br>GET<br>],<br><br><br><br><br><br><br><br><br><br>Logging: {<br>Enabled: true,<br>IncludeCookies: false,<br>Bucket: "my-logging-bucket.s3.amazonaws.com",<br>Prefix: ""<br>},<br><br><br><br><br><br>MinimumProtocolVersion: "TLSv1.2_2021",<br><br><br><br></font> | <font color="yellow">DistributionConfig: {<br>Aliases: {<br>Quantity: 1,<br>Items: [<br>...<br>]<br>},<br>Origins: {<br>Quantity: 2,<br>Items: [<br>{<br>...<br>},<br>{<br>...<br>}<br>]<br>},<br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br><br>ViewerCertificate: {<br>CloudFrontDefaultCertificate: false,<br>ACMCertificateArn: "arn:aws:acm:us-east-1:.....",<br>SSLSupportMethod: "sni-only",<br><br>Certificate: "arn:aws:acm:us-east-1:.....",<br>CertificateSource: "acm"<br>},</font> | <font color="yellow">DistributionConfig: {<br>Aliases: {<br>Quantity: 1,<br>Items: [<br>...<br>]<br>},<br>Origins: {<br>Quantity: 2,<br>Items: [<br>{<br>...<br>},<br>{<br>...<br>}<br>]<br>},<br><font color="cyan">DefaultCacheBehavior: {<br>ViewerProtocolPolicy: "redirect-to-https",<br>AllowedMethods: {<br>Quantity: 4,<br>Items: [<br>HEAD,<br>DELETE,<br>POST,<br>GET<br>],<br><font color="red">CachedMethods: {<br>Quantity: 2,<br>Items: [<br>HEAD,<br>GET<br>]<br>}<br>},<br>},<br><font color="cyan">Logging: {<br>Enabled: true,<br>IncludeCookies: false,<br>Bucket: "my-logging-bucket.s3.amazonaws.com",<br>Prefix: ""<br>},<br><font color="red">PriceClass: "PriceClass_All",<br><font color="yellow">ViewerCertificate: {<br>CloudFrontDefaultCertificate: false,<br>ACMCertificateArn: "arn:aws:acm:us-east-1:.....",<br>SSLSupportMethod: "sni-only",<br><font color="cyan">MinimumProtocolVersion: "TLSv1.2_2021",<font color="yellow"><br>Certificate: "arn:aws:acm:us-east-1:.....",<br>CertificateSource: "acm"<br>},</font> |
