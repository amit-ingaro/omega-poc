minikube-setup:
	minikube start
	kubectl config get-contexts
	kubectl config use-context minikube
	kubectl config current-context

check-context:
	@if [ "$$(kubectl config current-context)" = "minikube" ]; then \
		echo "Context is correct"; \
	else \
		echo "Error: Current context is not 'minikube'"; \
		exit 1; \
	fi

create-clean-argo-namespace: check-context
	echo "Setting up Argo namespace"
	kubectl delete namespace argo --ignore-not-found=true
	kubectl create namespace argo
	kubectl config set-context --current --namespace=argo

install-argo-local: check-context
	echo "Deploying Argo"
	kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.6/install.yaml
	kubectl apply -f ./argo/rbac/rbac.yml
	kubectl apply -f ./argo/rbac/controller-rbac.yml
	echo "Waiting for Argo server to be ready..."
	echo "Patching authorization..."
	kubectl wait --for=condition=Ready pods --all -n argo --timeout=300s
	kubectl patch deployment \
	  argo-server \
	  --namespace argo \
	  --type='json' \
	  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [ "server", "--auth-mode=client", "--auth-mode=server" ]}]'
	echo "Waiting for Argo server to be ready..."
	kubectl wait --for=condition=Ready pods --all -n argo --timeout=300s
	echo "Argo Workflows deployed successfully."
	echo "You can access the Argo UI at http://localhost:2746"

show-forwarded-ports: check-context
	ps -ef | grep port-forward

forward-ports: check-context
	kubectl -n argo port-forward deployment/argo-server 2746:2746

install-workflow-repo: check-context
    helm repo add omegawf https://github.com/amit-ingaro/omega-devops-poc/charts
    helm install omegawfchart omegawf/workflow-chart --namespace argo
