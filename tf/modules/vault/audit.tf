resource "vault_audit" "stdout" {
  type  = "file"
  options = {
    file_path = "stdout"
  }
}

