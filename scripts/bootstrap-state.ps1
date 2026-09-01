$ErrorActionPreference = "Stop"

$AwsRegion = "ap-northeast-2"
$AwsBucket = "phase1-cicd-tfstate-558807819624"
$GcpProject = "kdt4-1-506106"
$GcpRegion = "asia-northeast3"
$GcpBucket = "phase1-cicd-tfstate-kdt4-1-506106"

if (-not (aws s3api head-bucket --bucket $AwsBucket 2>$null)) {
  aws s3api create-bucket `
    --bucket $AwsBucket `
    --region $AwsRegion `
    --create-bucket-configuration LocationConstraint=$AwsRegion
}
aws s3api put-bucket-versioning --bucket $AwsBucket --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket $AwsBucket --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket $AwsBucket --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

gcloud storage buckets describe "gs://$GcpBucket" --project $GcpProject 2>$null
if ($LASTEXITCODE -ne 0) {
  gcloud storage buckets create "gs://$GcpBucket" --project $GcpProject --location $GcpRegion --uniform-bucket-level-access
}
gcloud storage buckets update "gs://$GcpBucket" --versioning

Write-Host "Remote state buckets are ready."
