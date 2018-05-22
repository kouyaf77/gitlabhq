module QA
  module Page
    module Project
      module Operations
        module Kubernetes
          class Show < Page::Base
            view 'app/views/projects/clusters/show.html.haml' do
            end

            def install_helm_tiller!
              within('.js-cluster-application-row-helm') do
                page.has_text?('Install')
                click_on 'Install'
                page.has_text?('Installed', wait: 300)
              end
            end

            def install_ingress!
              within('.js-cluster-application-row-ingress') do
                page.has_text?('Install')
                click_on 'Install'
                page.has_text?('Installed', wait: 300)
              end
            end

            def install_prometheus!
              within('.js-cluster-application-row-prometheus') do
                page.has_text?('Install')
                click_on 'Install'
                page.has_text?('Installed', wait: 300)
              end
            end

            def install_runner!
              within('.js-cluster-application-row-runner') do
                page.has_text?('Install')
                click_on 'Install'
                page.has_text?('Installed', wait: 300)
              end
            end
          end
        end
      end
    end
  end
end
