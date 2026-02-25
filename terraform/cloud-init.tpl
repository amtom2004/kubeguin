runcmd:
    -   curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -
    -   until kubectl get nodes | grep -q "Ready"; do sleep 2; done
    -   kubectl create namespace argocd
    -   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    -   until kubectl -n argocd get pods | grep argocd-server | grep -q "Running"; do sleep 5; done
    -   kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort", "ports":[{"port":443,"targetPort":8080,"nodePort":30443}]}}'
    -   echo "${argocd_app_b64}" | base64 -d > /home/ubuntu/kubeguin.yaml
    -   sleep 30
    -   kubectl apply -f /home/ubuntu/kubeguin.yaml