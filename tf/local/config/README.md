# Usage
Obtain the root vault token (ie. god mode) for initial setup, and then run the plan. 

## Root Token Access
- Login with `gcloud auth login` with a user that is part of a group with cloudkms admin/decrypt rights

```
gcloud auth login

export GCP_PROJECT="runwhen-dev-tiger"
export GCS_BUCKET_NAME="$GCP_PROJECT-vault"
export VAULT_TOKEN=$(gsutil cat gs://${GCS_BUCKET_NAME}/root-token.enc | \
  base64 --decode | \
  gcloud kms decrypt \
    --project ${GCP_PROJECT} \
    --location global \
    --keyring $GCS_BUCKET_NAME \
    --key $GCS_BUCKET_NAME-unseal-key \
    --ciphertext-file - \
    --plaintext-file - 
)

```
## Running the plan
- Set default app credentials 
```
gcloud auth application-default login
```

- Set GitHub Token (requires workflows and repo scopes - otherwise a 404 occurs)
```
export GITHUB_TOKEN=[GITHUB_TOKEN]
```

- Parallelism 
Run terraform with parallelism=1 to avoid external data shell conflicts (which seems like it works and is simpler than terraform module dependency chains)

```
terraform plan -parallelism=1
terraform apply -parallelism=1

```