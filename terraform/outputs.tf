output "vm_ip" {
    value = multipass_instance.kubeguin.ipv4
}

output "app_url" {
    value = "http://${multipass_instance.kubeguin.ipv4}:30080"
}

output "argocd_url" {
    value = "http://${multipass_instance.kubeguin.ipv4}:30443"
}

output "argocd_password_cmd" {
    value = "multipass exec kubeguin-vm -- kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}