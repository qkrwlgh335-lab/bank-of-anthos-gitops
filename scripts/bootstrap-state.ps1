param(
  [string]$AwsAccountId = "558807819624",
  [string]$AwsRegion = "ap-northeast-2",
  [string]$AwsBucket = "phase1-cicd-tfstate-558807819624",
  [string]$GcpProject = "kdt4-1-506106",
  [string]$GcpRegion = "asia-northeast3",
  [string]$GcpBucket = "phase1-cicd-tfstate-kdt4-1-506106"
)

$ErrorActionPreference = "Stop"

$ActualAwsAccount = aws sts get-caller-identity --query Account --output text
if ($LASTEXITCODE -ne 0 -or $ActualAwsAccount -ne $AwsAccountId) {
  throw "AWS safety check failed. Expected account '$AwsAccountId', received '$ActualAwsAccount'."
}

$ActualGcpProject = gcloud projects describe $GcpProject --format="value(projectId)"
if ($LASTEXITCODE -ne 0 -or $ActualGcpProject -ne $GcpProject) {
  throw "GCP safety check failed. Cannot access approved project '$GcpProject'."
}

aws s3api head-bucket --bucket $AwsBucket 2>$null
if ($LASTEXITCODE -ne 0) {
  aws s3api create-bucket `
    --bucket $AwsBucket `
    --region $AwsRegion `
    --create-bucket-configuration LocationConstraint=$AwsRegion
  if ($LASTEXITCODE -ne 0) { throw "Failed to create S3 state bucket '$AwsBucket'." }
}
aws s3api put-bucket-versioning --bucket $AwsBucket --versioning-configuration Status=Enabled
if ($LASTEXITCODE -ne 0) { throw "Failed to enable S3 versioning." }
aws s3api put-bucket-encryption --bucket $AwsBucket --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
if ($LASTEXITCODE -ne 0) { throw "Failed to enable S3 encryption." }
aws s3api put-public-access-block --bucket $AwsBucket --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
if ($LASTEXITCODE -ne 0) { throw "Failed to block public S3 access." }

gcloud storage buckets describe "gs://$GcpBucket" --project $GcpProject 2>$null
if ($LASTEXITCODE -ne 0) {
  gcloud storage buckets create "gs://$GcpBucket" --project $GcpProject --location $GcpRegion --uniform-bucket-level-access
  if ($LASTEXITCODE -ne 0) { throw "Failed to create GCS state bucket '$GcpBucket'." }
}
gcloud storage buckets update "gs://$GcpBucket" --project $GcpProject --versioning
if ($LASTEXITCODE -ne 0) { throw "Failed to enable GCS versioning." }

Write-Host "Remote state buckets are ready for AWS '$AwsAccountId' and GCP '$GcpProject'."
