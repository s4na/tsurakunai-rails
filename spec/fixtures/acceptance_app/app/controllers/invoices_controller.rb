# frozen_string_literal: true

class InvoicesController < ActionController::Base
  before_action :authenticate_account!
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def update
    @invoice = current_account.invoices.find(params[:id])
    if @invoice.update(invoice_params)
      render plain: "saved"
    else
      render :edit, status: 422
    end
  end

  def index
    @invoices = current_account.invoices.order(:id)
    # A deliberately stale controller variable proves that the partial uses its local.
    @invoice = @invoices.first
    render :index
  end

  private

  def current_account
    # Test fixture only: trusted Rack env populated by the acceptance runner.
    # A real application must use its own authenticated session/identity provider.
    request.env["acceptance.account"]
  end

  def authenticate_account!
    head :unauthorized unless current_account
  end

  def invoice_params
    params.require(:invoice).permit(:memo, :amount_cents)
  end

  def not_found
    head :not_found
  end
end
