class PwaController < ApplicationController
  def manifest
    render 'pwa/manifest', layout: false, content_type: 'application/json'
  end

  def service_worker
    render 'pwa/service_worker', layout: false, content_type: 'application/javascript'
  end
end
