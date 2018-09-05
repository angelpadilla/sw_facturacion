module SwFac
	class Tools < Config

		def consulta_saldo
			# Servicio utilizado para consultar los timbres disponibles en el entorno productivo

  		url_prod = URI("#{SwFac::UrlProduction}account/balance")
  		http = Net::HTTP.new(url_prod.host, url_prod.port)
			request = Net::HTTP::Get.new(url_prod)
			request["Authorization"] = "bearer #{@production_token}"
	    request.content_type = "application/json"
			request["Cache-Control"] = 'no-cache'

			response_1 = http.request(request)
			res = JSON.parse(response_1.body)
			response = {}

			if response_1.code == '200'
				response[:status] = '200'
				response[:saldo] = res['data']['saldoTimbres']
			else
				response[:status] = '401'
				response[:saldo] = ''
				# response[:error] = ""
			end

			return response

		rescue => e
			puts "Error: #{e}"
		end

		def valida_rfc(rfc)
			# Servicio para identificar que los RFC (emisores y receptores) que intervienen en el proceso sean válidos, 
			# es decir que estén en la LCO (Lista de Contribuyentes con Obligación ante el SAT).

			url = URI("#{SwFac::UrlProduction}lrfc/#{rfc}")
			http = Net::HTTP.new(url.host, url.port)
			request = Net::HTTP::Get.new(url)
			request["Authorization"] = "bearer #{@production_token}"
	    request.content_type = "application/json"
			request["Cache-Control"] = 'no-cache'
      request["Postman-Token"] = 'a663ff71-f97d-57c9-be0b-1b1cdc06871e'

      pet = http.request(request)
			parsed = JSON.parse(pet.body)
			response = {}

			if pet.code == '200'
				response[:status] = parsed['status']
				response[:rfc_consultado] = parsed['data']['contribuyenteRFC']
				response[:sncf] = parsed['data']['sncf']
				response[:subcontratacion] = parsed['data']['subcontratacion']
			else
				response[:status] = 'Error'
				response[:message] = parsed['message']
				response[:message_detail] = parsed['messageDetail']
			end

			return response

		rescue => e
			puts "Error: #{e}"
		end

		def consulta_no_certificado(no_certificado)
			# Servicio para validar el numero de certificado 

			url = URI("#{SwFac::UrlProduction}lco/#{no_certificado}")
			http = Net::HTTP.new(url.host, url.port)
			request = Net::HTTP::Get.new(url)
			request["Authorization"] = "bearer #{@production_token}"
	    request.content_type = "application/json"
			request["Cache-Control"] = 'no-cache'
      request["Postman-Token"] = 'e17ee551-7f7a-32a7-8fd8-6b53ea70e3c9'

      pet = http.request(request)
			parsed = JSON.parse(pet.body)
			response = {}

			if pet.code == '200'
				response[:status] = parsed['status']
				response[:certificado_consultado] = parsed['data']['noCertificado']
				response[:rfc] = parsed['data']['rfc']
				response[:valides_obligaciones] = parsed['data']['validezObligaciones']
				response[:status_certificado] = parsed['data']['estatusCertificado']
				response[:fecha_inicio] = parsed['data']['fechaInicio']
				response[:fecha_final] = parsed['data']['fechaFinal']
			else
				response[:status] = 'Error'
				response[:message] = parsed['message']
				response[:message_detail] = parsed['messageDetail']
			end

			return response
		end

	end
end