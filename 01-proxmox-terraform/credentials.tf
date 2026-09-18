resource "local_sensitive_file" "clusterapi_token" {
  content = yamlencode(merge(
    {
      k8s-csi = {
        token_id    = proxmox_virtual_environment_user_token.k8s-csi_token.user_id
        token_value = proxmox_virtual_environment_user_token.k8s-csi_token.value
      }
    },
    {
      for c in var.capi_clusters :
      c => {
        token_id    = proxmox_virtual_environment_user_token.clusterapi_token[c].user_id
        token_value = proxmox_virtual_environment_user_token.clusterapi_token[c].value
      }
    },
    {
      pve_exporter = {
        token_id    = proxmox_virtual_environment_user_token.pve_exporter_token.user_id
        token_value = proxmox_virtual_environment_user_token.pve_exporter_token.value
      }
  }))
  filename = "${path.module}/${local.tokens_file}"
}
