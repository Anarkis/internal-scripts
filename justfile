#! /usr/bin/env -S just --justfile

EKSCTL_CONFIG_FILE := env_var_or_default('EKSCTL_CONFIG_FILE', 'cluster/eksctl.yaml')
GITOPS_CONFIG_FILE := env_var_or_default('GITOPS_CONFIG_FILE', parent_directory(EKSCTL_CONFIG_FILE) + "/gitops.yaml")
GOURCE_CONFIG_FILE := env_var_or_default('GOURCE_CONFIG_FILE', ".gource.conf")
HOMEBREW_INSTALLER_PATH := env_var_or_default('HOMEBREW_INSTALLER_PATH', 'scripts/install-homebrew.bash')
KUBECTL_SLICE_TEMPLATE := "{{ if .metadata.namespace }}manifests/{{ .metadata.namespace }}{{ else }}manifests{{ end }}/resources/{{ .kind }}/{{ .metadata.name }}.yaml"
MAMBA_ROOT_PREFIX := env_var_or_default('MAMBA_ROOT_PREFIX', '~/micromamba')
MANIFESTS_PATH := env_var_or_default('MANIFESTS_PATH', 'manifests')
FLUX_NAMESPACE := env_var_or_default('FLUX_NAMESPACE', 'flux-system')
FLUX_GOTK_SYNC_PATH := env_var_or_default('FLUX_GOTK_SYNC_PATH', join(MANIFESTS_PATH, FLUX_NAMESPACE, "gotk-sync.yaml"))
VAULT_NAMESPACE := env_var_or_default('VAULT_NAMESPACE', 'vault')
VAULT_NAME := env_var_or_default('VAULT_NAME', 'vault')
VAULT_MANIFEST_PATH := env_var_or_default('VAULT_MANIFEST_PATH', MANIFESTS_PATH + "/" + VAULT_NAMESPACE + "/resources/Vault/" + VAULT_NAME + ".yaml")
YAMLLINT_CONFIG_FILE := env_var_or_default('YAMLLINT_CONFIG_FILE', '.yamllint')
YAMLFMT_CONFIG_FILE := env_var_or_default('YAMLFMT_CONFIG_FILE', '.yamlfmt')

_default:
    just --list

check-justfile-formatting:
    @just --unstable --fmt --check

mod rancher-desktop 'scripts/rancher-desktop.just'

##############
# Ruby Tasks #
##############

@bundle-install:
    bundle config set --local path .bundle
    bundle install --quiet

################
# Python Tasks #
################

find-anaconda-installation: install-fish
    #! /usr/bin/env fish
    if command --query conda
      command --search conda | string split / --right --max=2 | string match --entire /
    else
      for prefix in ~ ~/opt /usr/local /opt/homebrew /opt
        if test -x {$prefix}/anaconda3/bin/conda
          echo {$prefix}/anaconda3
          exit (true)
        end
      end
      exit (false)
    end

[no-exit-message]
has-python-environment: install-fish install-micromamba install-jq install-yq
    #! /usr/bin/env fish
    set --global --export MAMBA_ROOT_PREFIX {{ MAMBA_ROOT_PREFIX }}
    micromamba shell hook --shell fish | source
    micromamba env list --json \
      | jq \
        --arg environment /(yq --exit-status .name < environment.yaml) \
        --exit-status \
        --raw-output \
        '.envs[] | select(.|endswith($ARGS.named.environment))' \
      > /dev/null

@create-python-environment: install-fish install-micromamba
    #! /usr/bin/env fish
    set --global --export MAMBA_ROOT_PREFIX {{ MAMBA_ROOT_PREFIX }}
    micromamba shell hook --shell fish | source
    micromamba create --file=environment.yaml

@ensure-python-environment: install-micromamba
    just has-python-environment \
      || just create-python-environment

@update-python-environment: install-fish install-micromamba
    #! /usr/bin/env fish
    set --global --export MAMBA_ROOT_PREFIX {{ MAMBA_ROOT_PREFIX }}
    if just has-python-environment
      micromamba shell hook --shell fish | source
      micromamba update --file=environment.yaml
    else
      just create-python-environment
    end

##############################
# Package Installation Tasks #
##############################

@install-brew:
    command -v brew > /dev/null \
        || scripts/install-homebrew.rb

@brew-install command formula="{ command }": install-brew
    command -v {{ command }} > /dev/null \
        || brew install {{ if formula == "{ command }" { command } else { formula } }}

@go-install command package version:
    command -v {{ command }} > /dev/null \
        || go install {{ package }}@{{ version }}

@krew-install command plugin: install-kubectl-krew
    command -v {{ command }} > /dev/null \
        || kubectl-krew install {{ plugin }}

install-age: (brew-install "age")

@install-anaconda:
    just find-anaconda-installation > /dev/null \
      || brew-install conda anaconda

install-awscli: (brew-install "aws" "awscli")

install-bat: (brew-install "bat")

install-cmake: (brew-install "cmake")

install-cmctl: (brew-install "cmctl")

install-direnv: (brew-install "direnv")

install-eksctl: (brew-install "eksctl")

install-drone-envsubst:
    test "$(command -v envsubst)" = "${GOBIN}/envsubst" \
      || just go-install "drone-envsubst" "github.com/drone/envsubst/cmd/envsubst" "v1.0.3"

install-fasd: (brew-install "fasd")

install-ffmpeg: (brew-install "ffmpeg")

install-filterdiff: (brew-install "filterdiff" "patchutils")

install-fish: (brew-install "fish")

install-flux: (brew-install "flux" "fluxcd/tap/flux")

install-fzf: (brew-install "fzf")

install-fzy: (brew-install "fzy")

install-gh: (brew-install "gh")

install-git-delta: (brew-install "delta" "git-delta")

install-gnupg: (brew-install "gnupg")

install-go: (brew-install "go")

install-gomplate: (brew-install "gomplate")

install-gource: (brew-install "gource")

install-grype: (brew-install "grype")

install-helm: (brew-install "helm")

install-jd: (brew-install "jd")

install-jq: (brew-install "jq")

install-just: (brew-install "just")

install-k9s: (brew-install "k9s")

install-karpenter-convert: (go-install "karpenter-convert" "github.com/aws/karpenter/tools/karpenter-convert/cmd/karpenter-convert" "release-v0.32.x")

install-kfilt: (go-install "kfilt" "github.com/ryane/kfilt" "v0.0.7")

install-kubeconform: (brew-install "kubeconform")

install-kubectl: (brew-install "kubectl")

install-kubectl-cnpg: (krew-install "kubectl-cnpg" "cnpg")

install-kubectl-cert_manager: (krew-install "kubectl-cert_manager" "cert-manager")

install-kubectl-hns: (krew-install "kubectl-hns" "hns")

install-kubectl-krew: (brew-install "kubectl-krew" "krew")

install-kubectl-neat: (krew-install "kubectl-neat" "neat")

install-kubectl-slice: (krew-install "kubectl-slice" "slice")

install-kubent: (brew-install "kubent")

install-kubeseal: (brew-install "kubeseal")

install-kustomize: (brew-install "kustomize")

install-linkerd: (brew-install "linkerd")

install-micromamba: (brew-install "micromamba")

install-mksh: (brew-install "mksh")

install-nova: (brew-install "nova" "fairwindsops/tap/nova")

install-nushell: (brew-install "nu" "nushell")

install-ripgrep: (brew-install "rg" "ripgrep")

install-step: (brew-install "step")

install-step-kms-plugin: (go-install "step-kms-plugin" "github.com/smallstep/step-kms-plugin" "v0.13.1")

install-syft: (brew-install "syft")

install-trivy: (brew-install "trivy")

install-updatecli: (brew-install "updatecli" "updatecli/updatecli/updatecli")

install-vcluster: (brew-install "vcluster")

install-yamlfmt: (brew-install "yamlfmt")

install-yamllint: (brew-install "yamllint")

install-yq: (brew-install "yq")

#################
# Cluster Tasks #
#################

write-eksctl-schema: install-eksctl
    eksctl utils schema \
        > schemas/eksctl.schema.json

write-eksctl-config: bundle-install
    scripts/extract-markdown-codeblocks.rb --render-with-erb \
        < cluster/README.md \
        > {{ EKSCTL_CONFIG_FILE }}

write-gitops-config: write-eksctl-config
    scripts/yaml.rb \
        --uncomment \
        --extract=gitops \
        --header \
        --context \
        < {{ EKSCTL_CONFIG_FILE }} \
        > {{ GITOPS_CONFIG_FILE }}

setup-kms-keys: write-eksctl-config bundle-install
    scripts/setup-kms-keys.rb {{ EKSCTL_CONFIG_FILE }}

deploy-cluster: write-eksctl-config
    eksctl create cluster --config-file={{ EKSCTL_CONFIG_FILE }}

get-cluster-auth-config: install-kubectl
    kubectl get ConfigMap/aws-auth \
      --namespace=kube-system \
      --output=yaml

list-cluster-iam-identity-mapping-arns: install-kubectl install-yq install-jq
    just get-cluster-auth-config \
      | yq '.data | [.mapRoles, .mapUsers][]' \
      | yq --output-format=json \
      | jq --raw-output '.[] | .rolearn//.userarn' \
      | sort

list-aws-iam-user-arns: install-awscli install-jq
    aws iam list-users --output=json \
      | jq -r '.Users[].Arn'

list-aws-iam-role-arns: install-awscli install-jq
    aws iam list-roles --output=json \
      | jq -r '.Roles[].Arn'

list-eksctl-iam-identity-mapping-arns: write-eksctl-config install-yq
    yq '.iamIdentityMappings[].arn' \
      < {{ EKSCTL_CONFIG_FILE }} \
      | sort

detect-outdated-iam-identity-mappings: install-fish
    #! /usr/bin/env fish

    comm -23 \
      (just list-cluster-iam-identity-mapping-arns | sort | psub) \
      (just list-eksctl-iam-identity-mapping-arns | sort | psub) \
      | rg --invert-match role/eksctl-

detect-questionable-iam-identity-mappings: install-fish
    #! /usr/bin/env fish

    comm -23 \
      (just list-eksctl-iam-identity-mapping-arns | sort | psub) \
      (just list-aws-iam-user-arns list-aws-iam-role-arns | sort | psub)

delete-ack-iam-controller-service-account: install-kubectl
    kubectl delete ServiceAccount/ack-iam-controller --namespace=ack-system

get-cluster-name: write-eksctl-config
    yq '.metadata.name' {{ EKSCTL_CONFIG_FILE }}

create-flux-secret-from-ssh-keypair name namespace="github-org-rancher-eio": install-kubectl install-yq install-kubectl-neat
    kubectl get SSHKeyPair/{{ name }} \
      --namespace={{ namespace }} \
      --output=yaml \
      | yq '.status.secret.name' \
      | xargs --no-run-if-empty --max-args=1 \
        kubectl get --output=yaml --namespace={{ namespace }} Secret \
      | kubectl-neat \
      | yq '. \
        | .metadata.name = "flux-system" \
        | .metadata.namespace = "flux-system" \
        | .data["identity"] = .data["ssh-privatekey"] \
        | .data["identity.pub"] = .data["ssh-publickey"] \
        | del(.metadata.labels) \
        | del(.data["ssh-privatekey"]) \
        | del(.data["ssh-publickey"]) \
        '

get-cluster-kubeconfig clusterName: write-eksctl-config
    eksctl utils write-kubeconfig \
      --config-file={{ EKSCTL_CONFIG_FILE }} \
      --kubeconfig=$HOME/.kube/.config/{{ clusterName }}

get-cluster-kubernetes-version: write-eksctl-config
    scripts/yaml.rb \
        --extract=metadata.version \
        < {{ EKSCTL_CONFIG_FILE }}

upgrade-cluster: install-kubectl write-eksctl-config
    scripts/upgrade-cluster.rb

upgrade-control-plane-with-eksctl: install-eksctl write-eksctl-config
    @echo eksctl upgrade cluster --config-file={{ EKSCTL_CONFIG_FILE }}

upgrade-control-plane-with-awscli clusterName kubernetesVersion: install-awscli write-eksctl-config
    @echo aws eks update-cluster-version --cluster-name={{ clusterName }} --kubernetes-version={{ kubernetesVersion }}

upgrade-control-plane: install-eksctl install-awscli write-eksctl-config
    #! /usr/bin/env ruby

    require 'yaml'

    YAML.load_file("{{ EKSCTL_CONFIG_FILE }}", symbolize_names: true).then do |eksctl|
        eksctl => { metadata: { name:, version: } }
        puts "aws eks update-cluster-version --cluster-name=#{name} --kubernetes-version=#{version}"
        # puts "eksctl upgrade cluster --config-file={{ EKSCTL_CONFIG_FILE }}"
    end

upgrade-managed-node-groups: install-awscli write-eksctl-config
    #! /usr/bin/env ruby

    require 'yaml'

    YAML.load_file("{{ EKSCTL_CONFIG_FILE }}", symbolize_names: true).then do |eksctl|
        eksctl => { metadata: { name: }, managedNodeGroups: }
        clusterName = name
        managedNodeGroups.each do |managedNodeGroup|
            managedNodeGroup => { name: }
            puts "aws eks update-nodegroup-version --cluster-name=#{clusterName} --nodegroup-name=#{name}"
        end
    end

discover-addons kubernetesVersion: install-eksctl install-jq
    eksctl utils describe-addon-versions --kubernetes-version={{ kubernetesVersion }} -v0 \
        | jq -r '.Addons[] | [.AddonName, .AddonVersions[0].AddonVersion, .MarketplaceInformation.ProductUrl] | @tsv' \
        | sort \
        | column -t

upgrade-addons: install-eksctl write-eksctl-config
    eksctl update addon --config-file={{ EKSCTL_CONFIG_FILE }}

####################
# Kubernetes Tasks #
####################

@flux-bootstrap-arguments: write-gitops-config
    scripts/yaml.rb --extract=gitops.flux.gitProvider < {{ GITOPS_CONFIG_FILE }}
    scripts/yaml.rb --extract=gitops.flux.flags < {{ GITOPS_CONFIG_FILE }} \
      | scripts/yaml-to-arguments.rb --magic

@flux-install-arguments: write-gitops-config install-yq install-jq
    scripts/yaml.rb --extract=gitops.flux.flags < {{ GITOPS_CONFIG_FILE }} \
      | scripts/yaml.rb --extract=components-extra --context \
      | scripts/yaml-to-arguments.rb

flux-bootstrap: install-flux
    echo flux bootstrap $(just flux-bootstrap-arguments)

flux-check: install-flux
    flux check

flux-install: install-flux
    echo flux install $(just flux-install-arguments)

flux-upgrade: install-flux
    flux install --export $(just flux-install-arguments)

flux-reconcile: install-flux
    flux reconcile --namespace=flux-system source git flux-system
    flux reconcile --namespace=flux-system kustomization flux-system

list-certificates: install-kubectl install-yq
    kubectl get certificates --all-namespaces --output=yaml \
        | yq '.items[] | [.metadata.namespace, .metadata.name] | @tsv' \
        | column -t

list-certificates-in-namespace namespace: install-kubectl install-yq
    kubectl get certificate --namespace={{ namespace }} --output=yaml \
        | yq '.items[] | [.metadata.namespace, .metadata.name] | @tsv' \
        | column -t

check-certificate-status namespace certificate: install-cmctl
    cmctl status certificate --namespace={{ namespace }} {{ certificate }}

get-flux-kustomize-controller-iam-role-arn: install-kustomize install-kfilt install-yq
    kustomize build manifests/flux-system \
      | kfilt --kind=ServiceAccount \
      | kfilt --name=kustomize-controller \
      | yq '.metadata.annotations["eks.amazonaws.com/role-arn"]'

add-iam-role-arn-annotation-to-flux-kustomize-controller: install-kubectl
    kubectl annotate ServiceAccount kustomize-controller \
      --field-manager=flux-client-side-apply \
      --namespace=flux-system \
      eks.amazonaws.com/role-arn=$(just get-flux-kustomize-controller-iam-role-arn)

restart-flux-kustomize-controller: install-kubectl
    kubectl rollout restart Deployment/kustomize-controller --namespace=flux-system

fix-sops-for-flux: add-iam-role-arn-annotation-to-flux-kustomize-controller restart-flux-kustomize-controller

####################
# Repository Tasks #
####################

git-pull:
    git pull --ff-only

git-pull-rebase:
    true \
        && git stash \
        && git pull --rebase \
        && git stash pop

update-namespacing-rules: bundle-install
    test -f scripts/lib/namespacing-rules.yaml \
        || scripts/get-namespacing-rules.rb \
        > scripts/lib/namespacing-rules.yaml

detect-dirty-roundtrips:
    scripts/detect-dirty-roundtripping-manifests.rb

detect-duplicate-resources: bundle-install
    scripts/detect-duplicate-resources.rb

detect-misplaced-manifests: bundle-install
    scripts/detect-misplaced-manifests.rb

detect-namespacing-issues: bundle-install
    scripts/detect-namespacing-issues.rb

detect-unconventional-manifests: bundle-install
    scripts/detect-unconventional-manifests.rb

extract-containers: bundle-install
    scripts/extract-containers.rb

extract-markdown-codeblocks: bundle-install
    scripts/extract-markdown-codeblocks.rb

generate-image-automations: bundle-install
    scripts/generate-image-automations.rb

generate-kustomization-from-flux-helm-release: bundle-install
    scripts/generate-kustomization-from-flux-helm-release.rb

yaml-roundtrip:
    scripts/yaml-roundtrip.rb

show-me-where-it-goes:
    scripts/where-does-it-go.rb

put-it-where-it-goes:
    scripts/where-does-it-go.rb --write-to-files --force

summarize-resources: install-yq
    yq '[.kind, .metadata.name, .metadata.namespace // ""] | @tsv' \
      | sort \
      | column -t

generate-image-automations-for-crossplane-functions: install-fish install-yq
    #! /usr/bin/env fish

    scripts/generate-image-automations-from-crossplane-function.yq manifests/-/resources/Function/* \
      | just put-it-where-it-goes

    pushd manifests/default/resources/Function
    for manifest in *.yaml
      {{ justfile_directory() }}/scripts/generate-image-automations-from-crossplane-function.yq $manifest \
        | yq 'select(.kind == "Function")' \
        > {{ justfile_directory() }}/manifests/-/resources/Function/$manifest
      rm $manifest
    end
    popd
    rmdir manifests/default/resources/Function

generate-image-automations-for-crossplane-providers: install-fish install-yq
    #! /usr/bin/env fish

    scripts/generate-image-automations-from-crossplane-provider.yq manifests/-/resources/Provider/* \
      | just put-it-where-it-goes

    pushd manifests/default/resources/Provider
    for manifest in *.yaml
      {{ justfile_directory() }}/scripts/generate-image-automations-from-crossplane-provider.yq $manifest \
        | yq 'select(.kind == "Provider")' \
        > {{ justfile_directory() }}/manifests/-/resources/Provider/$manifest
      rm $manifest
    end
    popd
    rmdir manifests/default/resources/Provider

gource-save-config: install-gource
    gource \
      --bloom-intensity 0.75 \
      --bloom-multiplier 1.0 \
      --date-format '%G-W%V-%uT%T' \
      --dir-name-position 1.0 \
      --disable-auto-rotate \
      --elasticity 0.001 \
      --ffp \
      --fixed-user-size \
      --font-scale 0.8 \
      --hash-seed 69420 \
      --hide-bloom \
      --hide-filenames \
      --hide-progress \
      --highlight-all-users \
      --highlight-dirs \
      --key \
      --log-format custom \
      --no-vsync \
      --output-framerate 60 \
      --save-config {{ GOURCE_CONFIG_FILE }} \
      --start-position 0.5 \
      --stop-at-end \
      --stop-position 0.5 \
      --user-image-dir gravatars \
      --user-scale 1.2 \
      --viewport 1280x720

gource-output-custom-log: install-gource
    gource \
      --output-custom-log - . \
      | scripts/gource-custom-log-filter.rb

gource-output-ppm-stream startDate stopDate: install-gource gource-save-config
    just gource-output-custom-log \
      | gource \
        --load-config {{ GOURCE_CONFIG_FILE }} \
        --hide-mouse \
        --output-ppm-stream - \
        --path - \
        --start-date {{ startDate }} \
        --stop-at-end \
        --stop-date {{ stopDate }}

gource-render startDate stopDate: install-gource gource-save-config
    just gource-output-custom-log \
      | gource \
        --load-config {{ GOURCE_CONFIG_FILE }} \
        --path - \
        --start-date {{ startDate }} \
        --stop-date {{ stopDate }} \

gource-render-video startDate stopDate outputFilename: install-ffmpeg
    just gource-output-ppm-stream {{ startDate }} {{ stopDate }} \
      | ffmpeg -y -r 60 -f image2pipe -vcodec ppm -i - -vcodec libvpx -b:v 9000K {{ outputFilename }}

create-HelmRepository name url namespace="default" interval="60m": install-flux
    flux create source helm {{ name }} \
      --namespace={{ namespace }} \
      --url={{ url }} \
      --interval={{ interval }} \
      --export

create-HelmRelease name source chart namespace="default" interval="60m": install-flux
    flux create helmrelease {{ name }} \
      --release-name={{ name }} \
      --namespace={{ namespace }} \
      --target-namespace={{ namespace }} \
      --source=HelmRepository/{{ source }} \
      --chart={{ chart }} \
      --chart-interval={{ interval }} \
      --interval=1m \
      --export

remove-finalizers kind name namespace="default": install-kubectl
    kubectl patch {{ kind }}/{{ name }} \
      --namespace={{ namespace }} \
      --patch='{"metadata":{"finalizers":[]}}' \
      --type=merge

flux-retry kind name namespace="flux-system": install-flux
    flux suspend {{ kind }} {{ name }} --namespace={{ namespace }}
    flux resume {{ kind }} {{ name }} --namespace={{ namespace }}

get-karpenter-node-iam-role-name: install-kubectl install-yq
    kubectl get ConfigMap/karpenter-node \
      --namespace=scaling \
      --output=yaml \
      | yq '.data["iam.instanceProfile.name"]'

convert-karpenter-resources: install-karpenter-convert
    cat \
      manifests/-/resources/Provisioner/*.yaml \
      manifests.withSubstitutions/-/resources/AWSNodeTemplate/*.yaml \
      | karpenter-convert -f- \
      | sed -e "s/\$KARPENTER_NODE_ROLE/$(just get-karpenter-node-iam-role-name)/" \
      | scripts/where-does-it-go.rb --write-to-files

generate-image-automations-for-namespace namespace="default": install-kubectl bundle-install
    kubectl get pods \
      --namespace={{ namespace }} \
      --output=yaml \
      | scripts/convert-list-items-to-documents.rb \
      | scripts/extract-containers.rb \
        --namespace \
      | scripts/generate-image-automations.rb \
        --filter-prefix=cr.l5d.io/linkerd/proxy: \
        --filter-prefix=gcr.io/google_containers/pause: \
        --image-policies \
        --image-repositories \
        --no-image-update-automations

detect-ack-iam-issues: install-kubectl bundle-install
    kubectl get roles.iam.services.k8s.aws \
      --all-namespaces \
      --output=yaml \
      | scripts/convert-list-items-to-documents.rb \
      | scripts/detect-ack-iam-issues.rb

compare-chart-values helmChart thisVersion thatVersion: install-fish install-helm
    #! /usr/bin/env fish
    git diff --no-index --ignore-all-space \
      (helm show values {{ helmChart }} --version={{ thisVersion }} | psub) \
      (helm show values {{ helmChart }} --version={{ thatVersion }} | psub)

list-image-policies-defined namespace="*": install-yq
    git ls-files -- manifests/{{ namespace }}/resources/ImagePolicy/*.yaml \
      | xargs --no-run-if-empty --max-args=1 yq '.metadata | [.namespace, .name] | @tsv' \
      | awk '{ print $1 "/" $2 }' \
      | sort \
      | uniq

list-image-policies-referenced namespace="*": install-fish install-micromamba ensure-python-environment
    #! /usr/bin/env fish
    set --global --export MAMBA_ROOT_PREFIX {{ MAMBA_ROOT_PREFIX }}
    micromamba shell hook --shell fish | source
    micromamba activate (yq --exit-status .name < environment.yaml) | source
    scripts/extract-comments-from-yaml.py --git --path-prefix=manifests/{{ if namespace == "*" { "" } else { namespace + "/" } }} \
      | egrep -o '"\$imagepolicy":.+' \
      | tr -d '{" }' \
      | awk -F : '{ print $2 "/" $3 }' \
      | sort \
      | uniq

list-image-policies-in-use namespace="*": install-fish
    #! /usr/bin/env fish
    comm -12 \
      (just list-image-policies-defined "{{ namespace }}" | psub) \
      (just list-image-policies-referenced "{{ namespace }}" | psub)

list-image-policies-undefined namespace="*": install-fish
    #! /usr/bin/env fish
    comm -13 \
      (just list-image-policies-defined "{{ namespace }}" | psub) \
      (just list-image-policies-referenced "{{ namespace }}" | psub)

list-image-policies-unused namespace="*": install-fish
    #! /usr/bin/env fish
    comm -23 \
      (just list-image-policies-defined "{{ namespace }}" | psub) \
      (just list-image-policies-referenced "{{ namespace }}" | psub)

list-image-repositories-defined namespace="*": install-yq
    git ls-files -- manifests/{{ namespace }}/resources/ImageRepository/*.yaml \
      | xargs --no-run-if-empty --max-args=1 yq '.metadata | [.namespace, .name] | @tsv' \
      | awk '{ print $1 "/" $2 }' \
      | sort \
      | uniq

list-image-repositories-without-policies namespace="*": install-fish
    #! /usr/bin/env fish
    comm -23 \
      (just list-image-repositories-defined "{{ namespace }}" | psub) \
      (just list-image-policies-defined "{{ namespace }}" | psub)

list-local-helm-repositories: install-helm
    helm repo list \
      | awk 'NR > 1' \
      | column -t

purge-local-helm-repositories: install-helm
    just list-local-helm-repositories \
        | awk '{ print $1 }' \
        | xargs --no-run-if-empty --max-args=1 helm repo rm

list-committed-helm-repositories namespace="*":
    git ls-files -- manifests/{{ namespace }}/resources/HelmRepository/*.yaml \
      | xargs --no-run-if-empty --max-args=1 yq '[.metadata.name, .spec.url] | @tsv' \
      | column -t \
      | sort \
      | uniq

import-committed-helm-repositories namespace="*": install-helm install-ripgrep
    just list-committed-helm-repositories \
      | rg --fixed-strings --invert-match oci:// \
      | xargs --no-run-if-empty --max-args=2 helm repo add

@extract-helm-reference-from-release filename="-": install-yq
    yq '.spec.chart.spec | [.sourceRef.name, .chart, .version] | @tsv' {{ filename }} \
      | awk '{ print $1"/"$2,$3 }' \
      | column -t

@list-helm-releases-changed-in-branch branch namespace="{ branch }":
    git diff --name-only origin/{{ branch }} manifests/{{ if namespace == "{ branch }" { branch } else { namespace } }}/resources/HelmRelease/*.yaml

helm-release-versions-changed-in-branch branch: install-fish install-yq
    #! /usr/bin/env fish
    for manifest in (just list-helm-releases-changed-in-branch {{ branch }})
      join \
        (cat {$manifest} | just extract-helm-reference-from-release | psub) \
        (git show origin/{{ branch }}:{$manifest} | just extract-helm-reference-from-release | psub)
    end

check-versions-for-helm-releases-changed-in-branch branch: install-helm
    just list-helm-releases-changed-in-branch {{ branch }} \
      | xargs --no-run-if-empty --max-args=1 just extract-helm-reference-from-release \
      | awk '{ print $1 }' \
      | xargs --no-run-if-empty --max-args=1 helm search repo --versions

generate-updatecli-pipeline-for-helm-releases manifest="-": install-yq
    scripts/generate-updatecli-pipeline-from-helm-release.yq {{ manifest }} | just format-yaml

generate-updatecli-pipeline-for-helm-releases-changed-in-branch branch: install-yq
    #! /usr/bin/env fish

    for manifest in (just list-helm-releases-changed-in-branch {{ branch }})
      just generate-updatecli-pipeline-for-helm-releases $manifest
    end | yq eval-all '. as $document ireduce({}; . * $document)'

update-charts-for-helm-releases manifest="-" operation="diff": install-updatecli
    #! /usr/bin/env fish

    set --query GIT_AUTHOR_EMAIL || set --export GIT_AUTHOR_EMAIL (git config user.email)
    set --query GIT_AUTHOR_NAME  || set --export GIT_AUTHOR_NAME  (git config user.name)

    updatecli "{{ operation }}" --config (just generate-updatecli-pipeline-for-helm-releases {{ manifest }} | psub --suffix .yaml)

update-charts-for-helm-releases-changed-in-branch branch operation="diff": install-yq install-updatecli
    #! /usr/bin/env fish

    set --query GIT_AUTHOR_EMAIL || set --export GIT_AUTHOR_EMAIL (git config user.email)
    set --query GIT_AUTHOR_NAME  || set --export GIT_AUTHOR_NAME  (git config user.name)

    updatecli "{{ operation }}" --config (just generate-updatecli-pipeline-for-helm-releases-changed-in-branch {{ branch }} | psub --suffix .yaml)

compare-values-for-charts-changed-in-branch branch:
    just helm-release-versions-changed-in-branch {{ branch }} \
      | awk '$2 != $3' \
      | xargs --no-run-if-empty --max-args=3 just compare-chart-values

configure-git-to-prune-remote-branches:
    git config remote.origin.prune true

list-outdated-helm-releases: install-nova install-jq
    nova find --helm 2> /dev/null \
      | jq -r '.[] | select(.outdated) | [.namespace, .release, .Installed.version, .Latest.version] | @tsv' \
      | awk '{ print $1 "/" $2, $3, $4 }' \
      | sort \
      | column -t

helm-template manifest: install-helm install-yq install-fish
    #! /usr/bin/env fish

    set --local namespace (yq '.spec.targetNamespace // .metadata.namespace // "default"' {{ manifest }})
    set --local releaseName (yq '.spec.releaseName // .metadata.name' {{ manifest }})
    set --local chart (yq '.spec.chart.spec | [.sourceRef.name, .chart] | join("/")' {{ manifest }})
    set --local chartVersion (yq '.spec.chart.spec.version' {{ manifest }})

    helm template --namespace=$namespace $releaseName $chart --version=$chartVersion --values=(yq .spec.values {{ manifest }} | psub)

eks-identity-oidc-issuer: install-kubectl install-yq
    kubectl get Cluster/cluster \
      --namespace=scaling \
      --output=yaml \
      | yq --exit-status .status.identity.oidc.issuer

service-account-token-audiences: install-kubectl install-jq
    kubectl create token default \
      | cut -d. -f2 \
      | base64 --decode \
      | jq --exit-status --raw-output '.aud | @tsv' \
      | tr "\t" ","

inspect-manifests-changed-in-branch branch: install-jd install-jq install-yq install-yamlfmt
    scripts/inspect-manifests-changed-in-branch.zsh {{ branch }}

crd-version-diff apiGroup name v1 v2: install-fish install-kubectl install-yq
    #! /usr/bin/env fish

    git diff --no-index \
      (kubectl get CustomResourceDefinition/{{ name }}.{{ apiGroup }} --output=yaml | yq '.spec.versions[] | select(.name == "{{ v1 }}")' | psub) \
      (kubectl get CustomResourceDefinition/{{ name }}.{{ apiGroup }} --output=yaml | yq '.spec.versions[] | select(.name == "{{ v2 }}")' | psub)

seal-secret: install-kubeseal
    kubeseal \
      --controller-namespace=secrets \
      --format=yaml

detect-deprecated-resources includeHelm="false": install-kubent
    kubent --helm3="{{ includeHelm }}"

hns-config: install-kubectl-hns
    kubectl-hns config describe

hns-describe namespace="github": install-kubectl-hns
    kubectl-hns describe {{ namespace }}

hns-tree namespace="github": install-kubectl-hns
    kubectl-hns tree {{ namespace }}

# deletes the MutatingWebhookConfiguration for HNC
hack-hnc-delete-MutatingWebhookConfiguration: install-kubectl
    kubectl delete MutatingWebhookConfiguration/hnc-mutating-webhook-configuration

# deletes the ValidatingWebhookConfiguration for HNC
hack-hnc-delete-ValidatingWebhookConfiguration: install-kubectl
    kubectl delete ValidatingWebhookConfiguration/hnc-validating-webhook-configuration

# deletes both webhooks for HNC
hack-hnc-delete-webhooks: hack-hnc-delete-MutatingWebhookConfiguration hack-hnc-delete-ValidatingWebhookConfiguration

# pauses reconciling HNC, allow temporary manual changes
hack-hnc-suspend-reconciliation: install-flux
    flux suspend kustomization --namespace=hnc-system hnc-manager
    flux suspend kustomization --namespace=hnc-system hnc-manager-webhooks

# resumes reconciling HNC, undoes most manual changes
hack-hnc-resume-reconciliation: install-flux
    flux resume kustomization --namespace=hnc-system hnc-manager
    flux resume kustomization --namespace=hnc-system hnc-manager-webhooks

# triggers reconciliation early for HNC
hack-hnc-reconcile: install-flux
    flux reconcile kustomization --namespace=hnc-system hnc-manager
    flux reconcile kustomization --namespace=hnc-system hnc-manager-webhooks

# manually updates the HNC configuration (useful if you break the controller)
hack-hnc-configuration: install-kubectl
    just hack-hnc-suspend-reconciliation
    just hack-hnc-delete-webhooks
    kubectl apply --filename=manifests/-/resources/HNCConfiguration/config.yaml
    just hack-hnc-resume-reconciliation

vcluster-list: install-vcluster
    vcluster list

vcluster-connect vClusterName="github": install-vcluster
    vcluster connect {{ vClusterName }}

tcp-list: install-kubectl
    kubectl get tenantcontrolplanes.kamaji.clastix.io --all-namespaces

tcp-admin-kubeconfig name namespace="testing" port="56443": install-kubectl install-yq
    kubectl get "Secret/{{ name }}-admin-kubeconfig" --namespace="{{ namespace }}" --output=yaml \
      | yq '.data["admin.conf"]' \
      | base64 -d \
      | yq '.clusters[0].cluster.server = "https://127.0.0.1:{{ port }}"'

tcp-port-forward name namespace="testing" port="56443": install-kubectl
    kubectl port-forward "Service/{{ name }}" --namespace="{{ namespace }}" "{{ port }}:kube-apiserver"

tcp-kubectl name namespace="testing" arguments="": install-fish install-kubectl
    #! /usr/bin/env fish

    # just tcp-port-forward {{ name }} {{ namespace }} > /dev/null &
    kubectl --kubeconfig=(just tcp-admin-kubeconfig {{ name }} {{ namespace }} | psub) {{ arguments }}
    # jobs --pid %1 | xargs --no-run-if-empty kill

tcp-dashboard: install-kubectl
    kubectl port-forward Service/kamaji-console --namespace=kamaji-system 3000:http

linkerd-jaeger-dashboard: install-linkerd
    linkerd jaeger dashboard

linkerd-viz-dashboard: install-linkerd
    linkerd viz dashboard

substitutions-environment: install-yq
    scripts/substitutions-environment-from-flux-kustomizations.yq < {{ FLUX_GOTK_SYNC_PATH }}

apply-substitutions: install-drone-envsubst
    env $(just substitutions-environment) envsubst

format-yaml: install-yamlfmt install-yq
    yq 'with(select((.kind != "ConfigMap") and (.kind != "Secret")); sort_keys(..))' \
      | yamlfmt -in

format-yaml-in-place filename: install-ripgrep install-yamlfmt install-yq
    #! /usr/bin/env mksh

    set -o errexit

    yq --exit-status --inplace 'with(select((.kind != "ConfigMap") and (.kind != "Secret")); sort_keys(..))' {{ filename }}

    if rg --quiet -- --- {{ filename }}
    then yamlfmt --formatter=include_document_start=true {{ filename }}
    else yamlfmt --formatter=include_document_start=false {{ filename }}
    fi

normalize-helm-release-in-place filename: install-yq
    yq --inplace --from-file=scripts/normalize-helm-release.yq {{ filename }}
    just format-yaml-in-place {{ filename }}

normalize-helm-releases-in-place: install-ripgrep
    git ls-files manifests \
      | rg --fixed-strings /resources/HelmRelease/ \
      | xargs --no-run-if-empty --max-args=1 \
        just normalize-helm-release-in-place

normalize-flux-resource-in-place filename: install-yq
    scripts/normalize-flux-resource.yq --inplace {{ filename }}
    just format-yaml-in-place {{ filename }}

normalize-flux-resources-in-place: install-ripgrep
  #! /usr/bin/env fish

  rg --files-with-matches --fixed-strings .toolkit.fluxcd.io/v (git ls-files -- manifests | rg '[.]yaml$') \
    | xargs --no-run-if-empty --max-args=1 \
      just normalize-flux-resource-in-place

vault-unseal-config: install-yq
    yq '.spec.unsealConfig' < "{{ VAULT_MANIFEST_PATH }}" \
        | just apply-substitutions

vault-root-token-url: install-yq
    just vault-unseal-config \
        | yq '.aws | .s3Prefix |= sub("/+$", "") | "s3://\(.s3Bucket)/\(.s3Prefix)/vault-root"'

vault-kms-decrypt-options: install-yq
    just vault-unseal-config \
      | yq '.aws | [ \
        "--region=\(.kmsRegion)", \
        "--key-id=\(.kmsKeyId)", \
        "--encryption-context=Tool=bank-vaults" \
        ][]'

vault-root-token-encrypted-blob: install-awscli
    aws s3 cp $(just vault-root-token-url) - | base64 | tr -d "[[:space:]]"

vault-root-token: install-awscli install-yq
    aws kms decrypt \
      $(just vault-kms-decrypt-options) \
      --ciphertext-blob="$(just vault-root-token-encrypted-blob)" \
      --query="Plaintext" \
      --output=text \
      | base64 -d

vault-github-automation: bundle-install
    scripts/vault-github-automation.rb \
      --path="{{ VAULT_MANIFEST_PATH }}" \
      --force
    yq --inplace '\
      . \
      | .spec.bankVaultsImage line_comment="# {\"$imagepolicy\": \"vault:rancherlabs-eio-bank-vaults\"}" \
      | .spec.fluentdImage    line_comment="# {\"$imagepolicy\": \"vault:fluent-fluentd\"}" \
      | .spec.image           line_comment="# {\"$imagepolicy\": \"vault:rancherlabs-eio-vault\"}" \
      | .spec.statsdImage     line_comment="# {\"$imagepolicy\": \"vault:prom-statsd-exporter\"}" \
      ' {{ VAULT_MANIFEST_PATH }}
    just format-yaml-in-place {{ VAULT_MANIFEST_PATH }}

vault-find-role orgName repoName: install-yq
    yq --exit-status '\
      .spec.externalConfig.auth[] \
      | select(.path == "{{ orgName }}").roles[] \
      | select(.name == "{{ repoName }}")\
      ' {{ VAULT_MANIFEST_PATH }}

extract-github-repositories-from-vault-manifest: install-yq
    scripts/extract-github-repositories-from-vault-manifest.yq {{ VAULT_MANIFEST_PATH }}

find-problematic-github-repository-names: install-yq
    just extract-github-repositories-from-vault-manifest \
      | yq '.organizations[].repositories[] | select(.runnerNamesAreTooLong.minimal) | .fullName' \
      | sort

find-github-organization-id orgName: bundle-install
    scripts/find-github-repository-id.rb {{ orgName }}

find-github-repository-id orgName repoName: bundle-install
    scripts/find-github-repository-id.rb {{ orgName }} {{ repoName }}

find-gha-workflows-in-organization orgName: install-fish install-gh install-yamlfmt install-yq
    #! /usr/bin/env fish

    gh api graphql --paginate --slurp --field orgLogin="{{ orgName }}" \
    --raw-field query='
      query($orgLogin:String!, $endCursor:String) {
        organization(login: $orgLogin) {
          ... on Organization {
            repositories(first: 100, after: $endCursor) {
              pageInfo {
                endCursor
                hasNextPage
              }
              nodes {
                nameWithOwner
                defaultBranchRef {
                  name
                }
                ... on Repository {
                  object(expression: "HEAD:.github/workflows") {
                    ... on Tree {
                      entries {
                        path
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    ' | yq -P '
      .[].data.organization.repositories.nodes[]
      | select(.object.entries)
      | with(.;
        .
        | .repository = .nameWithOwner
        | del(.nameWithOwner)
        | .branch = .defaultBranchRef.name
        | del(.defaultBranchRef)
        | .workflows = .object.entries
        | del(.object)
        )
      | split_doc
    ' | yamlfmt -in

arc-ephemeral-runners-detect-failed: install-fish install-kubectl install-yq
    #! /usr/bin/env fish

    kubectl get EphemeralRunners --all-namespaces --output=yaml \
      | yq '
          .items[]
          | select(.status.phase == "Failed")
          | select(.status.reason == "TooManyPodFailures")
          | [(["--namespace",.metadata.namespace] | join("=")),([.kind, .metadata.name] | join("/"))]
          | @tsv'

list-linkerd-enabled-workloads: install-fish install-kubectl install-yq
    #! /usr/bin/env fish

    kubectl get pods --all-namespaces --output=yaml \
        | yq '
            .items[]
            | select(.metadata.annotations["linkerd.io/inject"] == "enabled")
            | .metadata.namespace ref $namespace
            | .metadata.ownerReferences[]
            | [$namespace, .kind, .name]
            | @tsv' \
        | uniq \
        | sort \
        | while read namespace kind name

        switch $kind
            case ReplicaSet
                kubectl get --namespace=$namespace $kind/$name --output=yaml \
                    | yq '
                      .metadata.namespace ref $namespace
                      | .metadata.ownerReferences[]
                      | [$namespace, .kind, .name]
                      | @tsv' \
                    | uniq \
                    | sort
            case StatefulSet
            case Cluster
            case '*'
                echo $namespace $kind $name
        end
    end

arc-ephemeral-runners-purge-failed: install-kubectl
    just arc-ephemeral-runners-detect-failed \
      | xargs --no-run-if-empty --max-args=2 kubectl delete

ack-update-iam-policies: bundle-install
    scripts/update-iam-policies.rb

report-reused-secrets: install-kubectl install-yq
    kubectl get --namespace=secrets Secrets -oyaml \
    | yq '.items[] | split_doc | select(.metadata.name | match("^import-")) | select(.data.credentials)' \
    | ruby -ryaml -rbase64 -rdigest/sha2 -e 'STDOUT.puts(YAML.dump(YAML.load_stream(STDIN, symbolize_names: true).group_by { |secret| Digest::SHA256.hexdigest(Base64.decode64(secret[:data][:credentials]).gsub(/[[:space:]]/,"")) }.map { |digest, secrets| [digest, { count: secrets.count, secrets: secrets.map { |secret| secret[:metadata][:name] }}] }.sort_by { |_digest, report| report[:count] }.to_h ))'

find-conflicting-push-secrets:
    {{justfile_directory()}}/scripts/check-push-secrets.rb | awk '/STATUS|CONFLICT/' | column -t

add-path-comments-to-yaml: install-yq
    scripts/add-path-comments.yq

nodepool-instance-types: install-yq install-ripgrep
    yq '.spec.template.spec.requirements[] | select(.key == "node.kubernetes.io/instance-type") | .values[]'  {{ MANIFESTS_PATH}}/-/resources/NodePool/*.yaml \
    | rg -vF -- --- \
    | sort -u

nodepool-ip-address-limits: install-awscli install-yq
    aws ec2 describe-instance-types \
      --filters Name=instance-type,Values=$(just nodepool-instance-types | tr "\n" "," | sed 's@,$@@') \
      --output=yaml \
      | yq '.InstanceTypes[] | [.InstanceType, .NetworkInfo.MaximumNetworkInterfaces, .NetworkInfo.Ipv4AddressesPerInterface] | @tsv' \
      | sort

flux-gitops-git-repository: install-yq
    yq 'select(.kind == "GitRepository")' < {{ FLUX_GOTK_SYNC_PATH }}

flux-gitops-kustomization: install-yq
    yq 'select(.kind == "Kustomization")' < {{ FLUX_GOTK_SYNC_PATH }}

@git-config-better-diffs: install-git-delta
    echo git config --global core.pager \"delta\"
    echo git config --global delta.features \"side-by-side line-numbers decorations\"
    echo git config --global delta.whitespace-error-style \"22 reverse\"
    echo git config --global diff.mnemonicprefix true
    echo git config --global diff.renameLimit \"4096\"
    echo git config --global diff.renames \"copies\"
    echo git config --global diff.tool \"git-icdiff\"
    echo git config --global interactive.diffFilter \"delta --color-only\"
    echo git config --global delta.decorations.commit-decoration-style \"bold yellow box ul\"
    echo git config --global delta.decorations.file-style \"bold yellow ul\"
