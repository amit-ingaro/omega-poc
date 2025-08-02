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

install-demo-workflow: check-context
	echo "Adding repo and installing demo workflow"
	helm repo add omegademo https://amit-ingaro.github.io/omega-devops-poc/demo-charts/
	helm install workflow-chart omegademo/workflow-demo

clean-demo-workflow: check-context
	echo " remove chart repo and uninstalling workflow-demo"
	helm repo remove omegademo
	helm uninstall workflow-demo --namespace argo

install-omega-workflow: check-context
	echo "Adding Omega workflow repo and installing workflow-chart"
	helm repo add omega-wf https://amit-ingaro.github.io/omega-devops-poc/helm/workflowchart/
	helm install omega-workflow omega-wf/workflow-chart --namespace argo

clean-omega-workflow: check-context
	echo "remove workflow chart repo and unintall helm workflow demo chart"
	helm repo remove omega-wf
	helm uninstall omega-workflow --namespace argo
