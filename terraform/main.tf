terraform {
    required_providers {
        multipass = {
            source = "larstobi/multipass"
            version = "~> 1.4"
        }
    }
}

provider multipass {}

resource "local_file" "kubeguin_app" {
    filename = "${path.module}/kubeguin.yaml"
    content = <<-YAML
        apiVersion: argoproj.io/v1alpha1
        kind: Application
        metadata:
            name: kubeguin
            namespace: argocd
        spec:
            project: default
            source:
                repoURL: ${var.github_repo}
                targetRevision: ${var.github_branch}
                path: ${var.k8s_path}
            destination:
                server: https://kubernetes.default.svc
                namespace: default
            syncPolicy:
                automated:
                    prune: true
                    selfHeal: true
                syncOptions:
                    -   CreateNamespace=true
    YAML
}

resource "local_file" "cloud_init" {
    filename = "${path.module}/cloud-init.yaml"
    content = templatefile("${path.module}/cloud-init.tpl", {
        argocd_app_b64 = base64encode(local_file.kubeguin_app.content)
    })
}

resource "multipass_instance" "kubeguin" {
    name = "kubeguin-vm"
    cpus = 2
    memory = "4GiB"
    disk = "15GiB"
    image = "22.04"

    cloudinit_file = "${path.module}/cloud-init.yaml"

    depends_on = [local_file.cloud_init]
}