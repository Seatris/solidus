module Spree
  module Api
    class LineItemsController < Spree::Api::BaseController
      before_action :load_order, only: [:create, :update, :destroy]
      around_action :lock_order, only: [:create, :update, :destroy]

      def new
      end

      def create
        variant = Spree::Variant.find(params[:line_item][:variant_id])
        @line_item = @order.contents.add(
          variant,
          params[:line_item][:quantity] || 1,
          {
            stock_location_quantities: params[:line_item][:stock_location_quantities]
          }.merge({ options: line_item_params[:options].to_h })
        )
        ####
        if variant.subscribable
          SolidusSubscriptions::LineItem.create!(
            interval_units: params[:interval_units] || 'month',
            interval_length: 1,
            subscribable_id: variant.id,
            quantity: @line_item.quantity,
            start_date: params[:start_date],
            end_date: params[:end_date],
            spree_line_item: @line_item
          )
        end
        ###
        if @line_item.errors.empty?
          respond_with(@line_item, status: 201, default_template: :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def update
        @line_item = find_line_item
        if @order.contents.update_cart(line_items_attributes)
          @line_item.reload
          respond_with(@line_item, default_template: :show)
        else
          invalid_resource!(@line_item)
        end
      end

      def destroy
        @line_item = find_line_item
        @order.contents.remove_line_item(@line_item)
        respond_with(@line_item, status: 204)
      end

      private

      def load_order
        @order ||= Spree::Order.includes(:line_items).find_by!(number: order_id)
        authorize! :update, @order, order_token
      end

      def find_line_item
        id = params[:id].to_i
        @order.line_items.detect { |line_item| line_item.id == id } ||
          raise(ActiveRecord::RecordNotFound)
      end

      def line_items_attributes
        { line_items_attributes: {
            id: params[:id],
            quantity: params[:line_item][:quantity],
            options: line_item_params[:options] || {}
        } }
      end

      def line_item_params
        params.require(:line_item).permit(permitted_line_item_attributes)
      end
    end
  end
end
