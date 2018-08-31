module SwFac
	class Tools < Config

		def consulta_saldo
			# to do
			# Description of method
		  # Params hash:
		  # - command: String, documentation about this parameter

		  uri = @production ? URI("#{SwFac::UrlProduction}account/balance") : URI("#{SwFac::UrlDev}account/balance")
  		token = @production ? @production_token : @dev_token
  		time = params.fetch(:time, Time.now)

  		http = Net::HTTP.new(url.host, url.port)

			request = Net::HTTP::Get.new(url)
			request["Authorization"] = "bearer #{token}"
	    request.content_type = "application/json"
			request["Cache-Control"] = 'no-cache'

			response = http.request(request)
			puts '------------------------- - - - - - - - -'
			puts response.code
			puts response.body
			res = JSON.parse(response.body)

			if response.code == '200'
				puts res['data']['saldoTimbres']
				# @timbres = res['data']['saldoTimbres']
			else
				# @timbres = 'error'
			end
			
		end

		def consulta_lrfc
			# to do
		end

		def consulta_no_certificado
			# to do
		end

	end
end