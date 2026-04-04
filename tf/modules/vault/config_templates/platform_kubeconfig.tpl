apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${certificate-authority-data}
    server: ${server_address}
  name: ${cluster_name}
contexts:
- context:
    cluster: ${cluster_name}
    user: ${user_name}
  name: ${context_name}
users:
- name: ${user_name}
  user: 
    token: ${token}
current-context: ${context_name}