module ApplicationHelper
	def hidden_div_if(condition, attributes = {}, &block)
		if condition
			attributes["style"] = "display: none"
		end
		content_tag("div", attributes, &block)
	end

	def find_order_number_from_reference(refer_line_id)
		order_number = LineItem.find(refer_line_id).line.order_number
	end
end

def markdown(content)
	@markdown ||= Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, space_after_headers: true, fenced_code_blocks: true)
	@markdown.render(content)
end
