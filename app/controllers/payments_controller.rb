#
#
# == License:
# Fairnopoly - Fairnopoly is an open-source online marketplace.
# Copyright (C) 2013 Fairnopoly eG
#
# This file is part of Fairnopoly.
#
# Fairnopoly is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# Fairnopoly is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Fairnopoly.  If not, see <http://www.gnu.org/licenses/>.
#
class PaymentsController < InheritedResources::Base
  respond_to :html
  actions :create
  before_filter :authorize_resource, only: [:show]

  def show
    return redirect_to resource.paypal_checkout_url
  end

  def create
    authorize create_or_update_target
    create!
  end

  private
    def create_or_update_target
      @payment = Payment.find_or_initialize_by_transaction_id(
        Transaction.find(params[:transaction_id]).id
      ) # Rails 4: find_or_initialize(transaction_id: ...)
    end
end