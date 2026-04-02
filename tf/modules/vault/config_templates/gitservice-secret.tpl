# RunWhen Git Service Machine Account
apiVersion: v1
kind: Secret
metadata:
  name: gitservice-secret
  namespace: flux-system
type: Opaque
data:
  password: ${password}
  username: ${username}