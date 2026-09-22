resource "local_sensitive_file" "clusterapi_token" {
  content = yamlencode(merge(
    {
      k8s-csi = {
        token_id    = proxmox_user_token.k8s-csi_token.user_id
        token_value = proxmox_user_token.k8s-csi_token.value
      }
    },
    {
      for c in var.capi_clusters :
      c => {
        token_id    = proxmox_user_token.clusterapi_token[c].user_id
        token_value = proxmox_user_token.clusterapi_token[c].value
      }
    },
    {
      imagebuilder = {
        token_id    = proxmox_user_token.imagebuilder_token.user_id
        token_value = proxmox_user_token.imagebuilder_token.value
      }
    }
  ))
  filename = "${path.module}/${local.tokens_file}"
}
