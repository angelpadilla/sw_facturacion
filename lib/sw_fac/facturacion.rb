
module SwFac
	class Facturacion < Tools

		def comp_pago(params={})
			# Sample params
			# params = {
			# 	uuid: '',
			# 	venta_folio: '',
			#   cp: '',
			# 	receptor_razon: 'Car zone',
			#   receptor_rfc: 'XAXX010101000',
			#   forma_pago: '01',
			#   total: 100.00,
			# 	time_pago: '',
			# 	time_now: '',
			# 	modena: '',
			# 	line_items: [
			# 		{
			# 			monto: 60.00,
			# 			moneda: '',
			# 		},
			# 	]
			# }

			puts " Datos --------"
			puts "-- Total params: #{params[:total]}"
			puts "--- Line items: "
			params[:line_items].each do |line|
				puts "--- #{line[:monto]}"
			end
			lines_total = params[:line_items].inject(0) {|sum, x| sum + x[:monto].to_f}

			puts "-- Suma de line_items: #{lines_total.round(2)}"

			if (lines_total.round(2) > params[:total].to_f)
				raise 'Error SW - la suma de los complementos de pago es mayor al total reportado' 
			end

			unless params[:time_pago] and params[:time_pago].size > 0
				raise "Error SW - la fecha de timbrado debe de estar presente"
			end



			uri = @production ? URI("#{SwFac::UrlProduction}cfdi33/stamp/customv1/b64") : URI("#{SwFac::UrlDev}cfdi33/stamp/customv1/b64")
			token = @production ? @production_token : @dev_token
			time_now = params.fetch(:time_now, (Time.now).strftime("%Y-%m-%dT%H:%M:%S"))
			time_pago = params[:time_pago]


			base_doc = %(<?xml version="1.0" encoding="UTF-8"?>
				<cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:pago10="http://www.sat.gob.mx/Pagos" xsi:schemaLocation="http://www.sat.gob.mx/cfd/3 http://www.sat.gob.mx/sitio_internet/cfd/3/cfdv33.xsd http://www.sat.gob.mx/Pagos http://www.sat.gob.mx/sitio_internet/cfd/Pagos/Pagos10.xsd" Version="3.3" SubTotal="0" Total="0" Moneda="XXX" TipoDeComprobante="P" >
					<cfdi:Emisor />
					<cfdi:Receptor UsoCFDI="P01"/>
					<cfdi:Conceptos>
						<cfdi:Concepto ClaveProdServ="84111506" Cantidad="1" ClaveUnidad="ACT" Descripcion="Pago" ValorUnitario="0" Importe="0" />
					</cfdi:Conceptos>
					<cfdi:Complemento>
						<pago10:Pagos Version="1.0">
							<pago10:Pago>
							</pago10:Pago>
						</pago10:Pagos>
					</cfdi:Complemento>
				</cfdi:Comprobante>)

			base_doc.delete!("\n")
			base_doc.delete!("\t")

			xml = Nokogiri::XML(base_doc)
			comprobante = xml.at_xpath("//cfdi:Comprobante")
			comprobante['Serie'] = 'P'
			comprobante['Folio'] = params[:venta_folio].to_s
			comprobante['Fecha'] = time_now
			comprobante['LugarExpedicion'] = params[:cp].to_s
			comprobante['NoCertificado'] = @serial
			comprobante['Certificado'] = @cadena
			emisor = xml.at_xpath("//cfdi:Emisor")
			emisor['Rfc'] = @rfc
			emisor['Nombre'] = @razon
			emisor['RegimenFiscal'] = @regimen_fiscal
			receptor = xml.at_xpath("//cfdi:Receptor")
			receptor['Nombre'] = params[:receptor_razon].to_s
			receptor['Rfc'] = params[:receptor_rfc].to_s

			child_pago = xml.at_xpath("//pago10:Pago")
			child_pago['FechaPago'] = time_pago
			child_pago['FormaDePagoP'] = params[:forma_pago].to_s
			child_pago['MonedaP'] = params.fetch(:moneda, 'MXN')
			child_pago['Monto'] = params[:total].round(2).to_s

			saldo_anterior = params[:total]

			params[:line_items].each_with_index do |line, index|
				monto = line[:monto].to_f
				child_pago_relacionado = Nokogiri::XML::Node.new "pago10:DoctoRelacionado", xml
				child_pago_relacionado['IdDocumento'] = params[:uuid]
				child_pago_relacionado['MonedaDR'] = line.fetch(:moneda, 'MXN') 
				child_pago_relacionado['MetodoDePagoDR'] = 'PPD'
				child_pago_relacionado['NumParcialidad'] = (index + 1).to_s

				child_pago_relacionado['ImpSaldoAnt'] = (saldo_anterior).round(2).to_s
				child_pago_relacionado['ImpPagado'] = monto.round(2).to_s
				child_pago_relacionado['ImpSaldoInsoluto'] = (saldo_anterior - monto).round(2).to_s
				saldo_anterior -= monto 

				child_pago.add_child(child_pago_relacionado)
			end

			# puts '---------------- Xml resultante comprobante de pago -----------------------'
			# puts xml.to_xml
			# puts '--------------------------------------------------------'

			path = File.join(File.dirname(__FILE__), *%w[.. tmp])
			id = SecureRandom.hex

			FileUtils.mkdir_p(path) unless File.exist?(path)
				File.write("#{path}/tmp_c_#{id}.xml", xml.to_xml)
				xml_path = "#{path}/tmp_c_#{id}.xml"
			cadena_path = File.join(File.dirname(__FILE__), *%w[.. cadena cadena33.xslt])

			File.write("#{path}/pem_#{id}.pem", @pem)
			key_pem_url = "#{path}/pem_#{id}.pem"
			sello = %x[xsltproc #{cadena_path} #{xml_path} | openssl dgst -sha256 -sign #{key_pem_url} | openssl enc -base64 -A]
			comprobante['Sello'] = sello

			File.delete("#{xml_path}")
			File.delete("#{key_pem_url}")

			# puts '------ comprobante de pago antes de timbre -------'
			# puts xml.to_xml

			base64_xml = Base64.encode64(xml.to_xml)
			request = Net::HTTP::Post.new(uri)
			request.basic_auth(token, "")
			request.content_type = "application/json"
			request["cache-control"] = 'no-cache'
			request.body = JSON.dump({
			"credentials" => {
				"id" => params[:venta_folio].to_s,
				"token" => token.to_s
			},
			"issuer" => {
				"rfc" => @rfc
			},
			"document" => {
				"ref-id": params[:venta_folio].to_s,
				"certificate-number": @serial,
				"section": "all",
				"format": "xml",
				"template": "letter",
				"type": "application/xml",
				"content": base64_xml
			}
			})

			req_options = {
				use_ssl: false,
			}

			json_response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
				http.request(request)
			end
			puts "-- #{json_response.code} --"
			puts "-- #{json_response.message} --"
			# puts "-- Body --"
			# puts json_response.body
			# puts '---'
			response = JSON.parse(json_response.body)

			if json_response.code == '200'
				decoded_xml = Nokogiri::XML(Base64.decode64(response['content']))
				timbre = decoded_xml.at_xpath("//cfdi:Complemento").children[1]
				response = {
				status: 200,
				message_error: '',
				xml: decoded_xml.to_xml,
				uuid: response['uuid'],
				fecha_timbrado: timbre['FechaTimbrado'],
				sello_cfd: timbre['SelloCFD'],
				sello_sat: timbre['SelloSAT'],
				no_certificado_sat: timbre['NoCertificadoSAT'],
				}
				return response
			else
				response = {
					status: json_response.code,
				message_error: "Error message: #{json_response.message}, #{response['message']} #{response['error_details']}",
				xml: '',
				uuid: '',
				fecha_timbrado: '',
				sello_cfd: '',
				sello_sat: '',
				no_certificado_sat: '',
				}
				return response
			end

		end

		def nota_credito(params={})
			# Sample params
			# params = {
			# 	uuid_relacionado: '',
			#   desc: '',
			# 	motivo: 'dev, mod',
			# 	series: '',
			# 	folio: '',
			# 	cp: '',
			# 	time: '',
			# 	receptor_razon: '',
				#	  receptor_rfc: '',
				#	  uso_cfdi: '',
			# }

			total = (params[:monto]).to_f
				subtotal = total / 1.16
				tax = total - subtotal

			uri = @production ? URI("#{SwFac::UrlProduction}cfdi33/stamp/customv1/b64") : URI("#{SwFac::UrlDev}cfdi33/stamp/customv1/b64")
			token = @production ? @production_token : @dev_token
			time = params.fetch(:time, (Time.now).strftime("%Y-%m-%dT%H:%M:%S"))


			base_doc = %(<?xml version="1.0" encoding="utf-8"?>
					<cfdi:Comprobante xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.sat.gob.mx/cfd/3 http://www.sat.gob.mx/sitio_internet/cfd/3/cfdv33.xsd" Version="3.3" Serie="#{params.fetch(:series, 'N')}" Folio="#{params[:folio]}" Fecha="#{time}" FormaPago="99" NoCertificado="#{@serial}" Certificado="#{@cadena}" SubTotal="#{subtotal.round(2)}" Moneda="#{params.fetch(:moneda, 'MXN')}" Total="#{total.round(2)}" TipoDeComprobante="E" MetodoPago="PUE" LugarExpedicion="#{params[:cp]}" xmlns:cfdi="http://www.sat.gob.mx/cfd/3">
						<cfdi:CfdiRelacionados TipoRelacion="01">
							<cfdi:CfdiRelacionado UUID="#{params[:uuid_relacionado]}" />
						</cfdi:CfdiRelacionados>
						<cfdi:Emisor Rfc="#{@rfc}" Nombre="#{@razon}" RegimenFiscal="#{@regimen_fiscal}" />
						<cfdi:Receptor Rfc="#{params[:receptor_rfc]}" Nombre="#{params[:receptor_razon]}" UsoCFDI="#{params.fetch(:uso_cfdi, 'G03')}" />
						<cfdi:Conceptos>
							<cfdi:Concepto ClaveUnidad="ACT" ClaveProdServ="84111506" NoIdentificacion="C" Cantidad="1.00" Unidad="Pieza" Descripcion="#{params.fetch(:desc, 'DICTAMEN CC FACTURA ORIGEN 0')}" ValorUnitario="#{subtotal.round(2)}" Importe="#{subtotal.round(2)}">
								<cfdi:Impuestos>
									<cfdi:Traslados>
										<cfdi:Traslado Base="#{subtotal.round(2)}" Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="#{tax.round(2)}" />
									</cfdi:Traslados>
								</cfdi:Impuestos>
							</cfdi:Concepto>
						</cfdi:Conceptos>
						<cfdi:Impuestos TotalImpuestosTrasladados="#{tax.round(2)}">
							<cfdi:Traslados>
								<cfdi:Traslado Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="#{tax.round(2)}" />
							</cfdi:Traslados>
						</cfdi:Impuestos>
					</cfdi:Comprobante>
				)

				base_doc.delete!("\n")
				base_doc.delete!("\t")

				xml = Nokogiri::XML(base_doc)
			comprobante = xml.at_xpath("//cfdi:Comprobante")

			path = File.join(File.dirname(__FILE__), *%w[.. tmp])
			id = SecureRandom.hex

			FileUtils.mkdir_p(path) unless File.exist?(path)
				File.write("#{path}/tmp_n_#{id}.xml", xml.to_xml)
				xml_path = "#{path}/tmp_n_#{id}.xml"
			cadena_path = File.join(File.dirname(__FILE__), *%w[.. cadena cadena33.xslt])

			File.write("#{path}/pem_#{id}.pem", @pem)
			key_pem_url = "#{path}/pem_#{id}.pem"
			sello = %x[xsltproc #{cadena_path} #{xml_path} | openssl dgst -sha256 -sign #{key_pem_url} | openssl enc -base64 -A]
			comprobante['Sello'] = sello

			File.delete("#{xml_path}")
			File.delete("#{key_pem_url}")

			puts '------ nota antes de timbre -------'
			puts xml.to_xml

				base64_xml = Base64.encode64(xml.to_xml)
				
			request = Net::HTTP::Post.new(uri)
			request.basic_auth(token, "")
			request.content_type = "application/json"
			request["cache-control"] = 'no-cache'
			request.body = JSON.dump({
				"credentials" => {
					"id" => "#{params[:folio]}",
					"token" => token
				},
				"issuer" => {
					"rfc" => @rfc
				},
				"document" => {
				"ref-id": "#{params[:folio]}",
				"certificate-number": @serial,
				"section": "all",
				"format": "xml",
				"template": "letter",
				"type": "application/xml",
				"content": base64_xml
				}
			})

			req_options = {
				use_ssl: false,
			}

			json_response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
				http.request(request)
			end


			puts "-- #{json_response.code} --"
			puts "-- #{json_response.message} --"
			# puts "-- Body --"
			# puts json_response.body
			# puts '---'
			response = JSON.parse(json_response.body)

			if json_response.code == '200'
				decoded_xml = Nokogiri::XML(Base64.decode64(response['content']))
				timbre = decoded_xml.at_xpath("//cfdi:Complemento").children.first

				response = {
				status: 200,
				message_error: '',
				xml: decoded_xml.to_xml,
				uuid: response['uuid'],
				fecha_timbrado: timbre['FechaTimbrado'],
				sello_cfd: timbre['SelloCFD'],
				sello_sat: timbre['SelloSAT'],
				no_certificado_sat: timbre['NoCertificadoSAT'],
				}
				return response
			else
				response = {
					status: json_response.code,
				message_error: "Error message: #{json_response.message}, #{response['message']} #{response['error_details']}",
				xml: '',
				uuid: '',
				fecha_timbrado: '',
				sello_cfd: '',
				sello_sat: '',
				no_certificado_sat: '',
				}
				return response
			end


		end

		def cancela_doc(params={})
			# Sample params
			# params = {
			# 	uuid: '',
			# 	rfc_emisor: '',
			# 	motivo: '02',
			# 	key_password: '', # optional
			# 	cer_cadena: '', # optional
			# 	key_pem: '' # optional
			# }

			uri = @production ? URI("#{SwFac::UrlProduction}cfdi33/cancel/csd") : URI("#{SwFac::UrlDev}cfdi33/cancel/csd")
			token = @production ? @production_token : @dev_token
			# time = params.fetch(:time, (Time.now).strftime("%Y-%m-%dT%H:%M:%S"))


			request = Net::HTTP::Post.new(uri)
			request["Authorization"] = "bearer #{token}"
			request.content_type = "application/json"
			request["Cache-Control"] = 'no-cache'
			request["Postman-Token"] = '30b35bb8-534d-51c7-6a5c-e2c98a0c9395'
			request.body = JSON.dump({
			'uuid': params[:uuid],
			"password": params.fetch(:key_password, @key_pass),
			"rfc": params.fetch(:rfc_emisor, @rfc),
			"motivo": '02',
			"b64Cer": params.fetch(:cer_cadena, @cadena), 
			"b64Key": params.fetch(:key_pem, @pem_cadena) 
			})

			req_options = {
			use_ssl: false,
			}

			json_response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
				http.request(request)
			end

			puts "-- #{json_response.code} --"
			puts "-- #{json_response.message} --"
			# puts "-- Body --"
			# puts json_response.body
			# puts '---'
			response = JSON.parse(json_response.body)

			if json_response.code == '200'
				decoded_xml = response['data']['acuse']

				response = {
				status: 200,
				message_error: '',
				xml: decoded_xml,
				}

				return response
			else

				response ={
					status: json_response.code,
				message_error: "Error message: #{json_response.message}, #{response['message']} #{response['error_details']}",
				xml: '',
				}

				return response
			end

		end

		def timbra_v4(params={})
			puts "---- SwFacturacion:facturacion:timbra_v4"

			### sample params
			# 
			# params = {
			# 	moneda: 'MXN',
			# 	series: 'FA',
			# 	folio: '003',
			# 	forma_pago: '',
			# 	metodo_pago: 'PUE',
			# 	cp: '47180',
			# 	receptor_razon: 'Car zone',
			# 	receptor_rfc: '',
			# 	receptor_regimen: '',
			# 	uso_cfdi: 'G03',
			#   time: "%Y-%m-%dT%H:%M:%S",
			# 	line_items: [
			# 		{
			# 			clave_prod_serv: '78181500',
			#  			clave_unidad: 'E48',
			#  			unidad: 'Servicio',
			#  			sku: 'serv001',
			#  			cantidad: 1,
			#  			descripcion: 'Servicio mano de obra',
			#  			valor_unitario: 100.00,
			#  			descuento: 0.00,
			#  			tax_included: true,
			#           retencion_iva: 0, 6, 16
			#  			# Optional parameters
			# 		},
			# 	]

			# }
			
			uri = @production ? URI("#{SwFac::UrlProduction}cfdi33/stamp/customv1/b64") : URI("#{SwFac::UrlDev}cfdi33/stamp/customv1/b64")
			token = @production ? @production_token : @dev_token
			time = params.fetch(:time, (Time.now).strftime("%Y-%m-%dT%H:%M:%S"))
		end

		def timbra_doc(params={})
			### sample params
			# 
			# params = {
			# 	moneda: 'MXN',
			# 	series: 'FA',
			# 	folio: '003',
			# 	forma_pago: '',
			# 	metodo_pago: 'PUE',
			# 	cp: '47180',
			# 	receptor_razon: 'Car zone',
			# 	receptor_rfc: '',
			# 	uso_cfdi: 'G03',
			#   time: "%Y-%m-%dT%H:%M:%S",
			# 	line_items: [
			# 		{
			# 			clave_prod_serv: '78181500',
			#  			clave_unidad: 'E48',
			#  			unidad: 'Servicio',
			#  			sku: 'serv001',
			#  			cantidad: 1,
			#  			descripcion: 'Servicio mano de obra',
			#  			valor_unitario: 100.00,
			#  			descuento: 0.00,
			#  			tax_included: true,
			#           retencion_iva: 0, 6, 16
			#  			# Optional parameters
			# 		},
			# 	]

			# }
			
			puts "---- SwFacturacion:facturacion:timbra_doc"


			uri = @production ? URI("#{SwFac::UrlProduction}cfdi33/stamp/customv1/b64") : URI("#{SwFac::UrlDev}cfdi33/stamp/customv1/b64")
			token = @production ? @production_token : @dev_token
			time = params.fetch(:time, (Time.now).strftime("%Y-%m-%dT%H:%M:%S"))

			xml = Nokogiri::XML(SwFac::DocBase)
			comprobante = xml.at_xpath("//cfdi:Comprobante")
			comprobante['TipoCambio'] = '1'
			comprobante['TipoDeComprobante'] = 'I'
			comprobante['Serie'] = params.fetch(:series, 'FA').to_s
			comprobante['Folio'] = params.fetch(:folio).to_s
			comprobante['Fecha'] = time.to_s
			comprobante['FormaPago'] = params.fetch(:forma_pago, '01')
			comprobante['MetodoPago'] = params.fetch(:metodo_pago, 'PUE')
			comprobante['LugarExpedicion'] = params.fetch(:cp, '')
			comprobante['NoCertificado'] = @serial
			comprobante['Certificado'] = @cadena

			emisor = xml.at_xpath("//cfdi:Emisor")
			emisor['Nombre'] = @razon
			emisor['RegimenFiscal'] = @regimen_fiscal
			emisor['Rfc'] = @rfc

			receptor = xml.at_xpath("//cfdi:Receptor")
			receptor['Nombre'] = params.fetch(:receptor_razon, '')
			receptor['Rfc'] = params.fetch(:receptor_rfc, '')
			receptor['UsoCFDI'] = params.fetch(:uso_cfdi, 'G03')

			# retencion_iva = params.fetch(:retencion_iva, 0)

			impuestos = xml.at_xpath("//cfdi:Impuestos")
			traslados = Nokogiri::XML::Node.new "cfdi:Traslados", xml


			puts '--- sw_fac time -----'
			puts time
			puts '--------'

			conceptos = xml.at_xpath("//cfdi:Conceptos")

			line_items = params[:line_items]

			suma_total = 0.00
			subtotal = 0.00
			suma_iva = 0.00
			suma_ret = 0.00

			line_items.each do |line|
			ret_iva = line.fetch(:retencion_iva, 0)
			puts ret_iva


			## revisando si la linea tiene iva 0
			if line[:tax_included] == true
				# if line[:tipo_impuesto] == '004'
				# 	valor_unitario = (line[:valor_unitario].to_f)
				# else
				# end
				valor_unitario = ((line[:valor_unitario]).to_f) / 1.16
			else
				valor_unitario = (line[:valor_unitario].to_f)
			end

			cantidad = line[:cantidad].to_f
			total_line = cantidad * valor_unitario

			# if line[:tipo_impuesto] == '004'
				# total_acumulator = cantidad * valor_unitario
			# else
				# total_acumulator = cantidad * valor_unitario * 1.16
			# end
			
			total_acumulator = cantidad * valor_unitario * 1.16

			importe_iva = total_acumulator - total_line 
			subtotal += total_line 
			suma_iva += importe_iva
			suma_total += total_acumulator 

			puts "--- 01"
			## calculando retencion de IVA en caso de tener
			if ret_iva > 0
				if ret_iva == 6
						importe_ret_linea = (total_line * 1.06) - total_line
				elsif ret_iva == 16
					importe_ret_linea = importe_iva
				end
			else
				importe_ret_linea = 0
			end
			puts "--- 02"
			suma_ret += importe_ret_linea
				

			## Creando y poblando CFDI:CONCEPTO
			child_concepto = Nokogiri::XML::Node.new "cfdi:Concepto", xml
			child_concepto['ClaveProdServ'] = line[:clave_prod_serv].to_s
			child_concepto['NoIdentificacion'] = line[:sku].to_s 
			child_concepto['ClaveUnidad'] = line[:clave_unidad].to_s
			child_concepto['Unidad'] = line[:unidad].to_s
			child_concepto['Descripcion'] = line[:descripcion].to_s
			child_concepto['Cantidad'] = cantidad.to_s
			child_concepto['ValorUnitario'] = valor_unitario.round(4).to_s
			child_concepto['Importe'] = total_line.round(4).to_s
			# child_concepto['Descuento'] = line.fetch(:descuento, 0.00).round(6).to_s


			## Creando cdfi:Impuestos para cada linea
			child_impuestos = Nokogiri::XML::Node.new "cfdi:Impuestos", xml

			## Creando cfdi:Traslados para cada linea
			child_traslados = Nokogiri::XML::Node.new "cfdi:Traslados", xml
			child_traslado = Nokogiri::XML::Node.new "cfdi:Traslado", xml
			child_traslado['Base'] = total_line.round(4).to_s
			child_traslado['Impuesto'] = '002'
			child_traslado['TipoFactor'] = "Tasa"
			child_traslado['TasaOCuota'] = '0.160000'
			child_traslado['Importe'] = importe_iva.round(4).to_s

			# if line[:tipo_impuesto] == '004'
			# 	child_traslado['TasaOCuota'] = '0.000000'
			# else 
			# end


			# Joining all up
			child_traslados.add_child(child_traslado)
			child_impuestos.add_child(child_traslados)
			child_concepto.add_child(child_impuestos)
			conceptos.add_child(child_concepto)
			
			## Creando cfdi:Retenciones para cada linea en caso de tener
			if ret_iva > 0
				child_retenciones = Nokogiri::XML::Node.new "cfdi:Retenciones", xml
				child_retencion = Nokogiri::XML::Node.new "cfdi:Retencion", xml
				child_retencion['Base'] = total_line.round(4).to_s
				child_retencion['Impuesto'] = '002'
				child_retencion['TipoFactor'] = "Tasa"

				if ret_iva == 6
					child_retencion['TasaOCuota'] = "0.060000"
				elsif ret_iva == 16
					child_retencion['TasaOCuota'] = "0.160000"
				end

				child_retencion['Importe'] = importe_ret_linea.round(4).to_s

				child_retenciones.add_child(child_retencion)
				child_impuestos.add_child(child_retenciones)
			end


			# ??? 
			end

			puts '------ Totales -----'
			puts "Total suma = #{suma_total.round(2)}"
			puts "SubTotal suma = #{subtotal.round(2)}"
			puts "Suma iva = #{suma_iva.round(2)}"
			puts "Suma restenciones = #{suma_ret.round(2)}"

			comprobante['Moneda'] = params.fetch(:moneda, 'MXN')
			comprobante['SubTotal'] = subtotal.round(2).to_s


			## Poblanco cfdi:Impuestos
			impuestos['TotalImpuestosRetenidos'] = suma_ret.round(2).to_s if suma_ret > 0
			impuestos['TotalImpuestosTrasladados'] = suma_iva.round(2).to_s

			## filling default retencion info
			if suma_ret > 0
				retenciones = Nokogiri::XML::Node.new "cfdi:Retenciones", xml
				retencion_child = Nokogiri::XML::Node.new "cfdi:Retencion", xml
				retencion_child['Impuesto'] = "002"
				retencion_child['Importe'] = suma_ret.round(2).to_s
				# retencion_child['TipoFactor'] = "Tasa"

				retenciones.add_child(retencion_child)
				impuestos.add_child(retenciones)
				comprobante['Total'] = (suma_total - suma_ret).round(2).to_s
			else
				comprobante['Total'] = suma_total.round(2).to_s
			end


			## filling traslado info
			traslado_child = Nokogiri::XML::Node.new "cfdi:Traslado", xml
			traslado_child['Impuesto'] = '002'
			traslado_child['TipoFactor'] = 'Tasa'
			traslado_child['TasaOCuota'] = '0.160000'
			traslado_child['Importe'] = suma_iva.round(2).to_s
			traslados.add_child(traslado_child)
			impuestos.add_child(traslados)



			# puts '------ Totales -----'
			# puts "Total suma = #{comprobante['Total']}"
			# puts "SubTotal suma = #{subtotal}"
			# puts "Suma iva = #{suma_iva}"
			# puts "Suma retenciones = #{impuestos['TotalImpuestosRetenidos']}" if suma_ret > 0



			path = File.join(File.dirname(__FILE__), *%w[.. tmp])
			id = SecureRandom.hex

			FileUtils.mkdir_p(path) unless File.exist?(path)
			File.write("#{path}/tmp_#{id}.xml", xml.to_xml)
			xml_path = "#{path}/tmp_#{id}.xml"
			cadena_path = File.join(File.dirname(__FILE__), *%w[.. cadena cadena33.xslt])

			# puts File.read(cadena_path)
			File.write("#{path}/pem_#{id}.pem", @pem)
			key_pem_url = "#{path}/pem_#{id}.pem"
			sello = %x[xsltproc #{cadena_path} #{xml_path} | openssl dgst -sha256 -sign #{key_pem_url} | openssl enc -base64 -A]
			comprobante['Sello'] = sello

			File.delete("#{xml_path}")
			File.delete("#{key_pem_url}")

			puts '---- SW GEM comprobante sin timbrar ------'
			puts xml.to_xml
			puts '-------------------------'

			base64_xml = Base64.encode64(xml.to_xml)
			request = Net::HTTP::Post.new(uri)
			request.basic_auth(token, "")
			request.content_type = "application/json"
			request["cache-control"] = 'no-cache'
			request.body = JSON.dump({
				"credentials" => {
					"id" => params.fetch(:folio).to_s,
					"token" => token
				},
				"issuer" => {
					"rfc" => emisor['Rfc']
				},
				"document" => {
					"ref-id": params.fetch(:folio).to_s,
					"certificate-number": comprobante['NoCertificado'],
					"section": "all",
					"format": "xml",
					"template": "letter",
					"type": "application/xml",
					"content": base64_xml
				}
			})

			req_options = {
				use_ssl: false,
			}

			json_response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
				http.request(request)
			end

			puts "-- #{json_response.code} --"
			puts "-- #{json_response.message} --"
			# puts "-- Body --"
			# puts json_response.body
			# puts '---'
			response = JSON.parse(json_response.body)

			if json_response.code == '200'
				decoded_xml = Nokogiri::XML(Base64.decode64(response['content']))
				timbre = decoded_xml.at_xpath("//cfdi:Complemento").children.first

				response = {
					status: 200,
					message_error: '',
					xml: decoded_xml.to_xml,
					uuid: response['uuid'],
					fecha_timbrado: timbre['FechaTimbrado'],
					sello_cfd: timbre['SelloCFD'],
					sello_sat: timbre['SelloSAT'],
					no_certificado_sat: timbre['NoCertificadoSAT'],
				}

				return response
			else

				response ={
					status: json_response.code,
					message_error: "Error message: #{json_response.message}, #{response['message']} #{response['error_details']}",
					xml: '',
					uuid: '',
					fecha_timbrado: '',
					sello_cfd: '',
					sello_sat: '',
					no_certificado_sat: '',
				}

				return response
			end



		end

		def timbra_doc_cero(params={})
			puts "---- SwFacturacion:facturacion:timbra_doc_cero"
			# params = {
			# 	moneda: 'MXN',
			# 	series: 'FA',
			# 	folio: '003',
			# 	forma_pago: '',
			# 	metodo_pago: 'PUE',
			# 	cp: '47180',
			# 	receptor_razon: 'Car zone',
			# 	receptor_rfc: '',
			# 	uso_cfdi: 'G03',
			#   time: "%Y-%m-%dT%H:%M:%S",
			# 	line_items: [
			# 		{
			# 			clave_prod_serv: '78181500',
			#  			clave_unidad: 'E48',
			#  			unidad: 'Servicio',
			#  			sku: 'serv001',
			#  			cantidad: 1,
			#  			descripcion: 'Servicio mano de obra',
			#  			valor_unitario: 100.00,
			#  			# Optional parameters
			# 		},
			# 	]

			# }

			uri = @production ? URI("#{SwFac::UrlProduction}cfdi33/stamp/customv1/b64") : URI("#{SwFac::UrlDev}cfdi33/stamp/customv1/b64")
			token = @production ? @production_token : @dev_token
			time = params.fetch(:time, (Time.now).strftime("%Y-%m-%dT%H:%M:%S"))

			xml = Nokogiri::XML(SwFac::DocBaseCero)
			comprobante = xml.at_xpath("//cfdi:Comprobante")
			comprobante['TipoCambio'] = '1'
			comprobante['TipoDeComprobante'] = 'I'
			comprobante['Serie'] = params.fetch(:series, 'FA').to_s
			comprobante['Folio'] = params.fetch(:folio, '1').to_s
			comprobante['Fecha'] = time.to_s
			comprobante['FormaPago'] = params.fetch(:forma_pago, '01')
			comprobante['MetodoPago'] = params.fetch(:metodo_pago, 'PUE')
			comprobante['LugarExpedicion'] = params.fetch(:cp, '55555')
			comprobante['NoCertificado'] = @serial
			comprobante['Certificado'] = @cadena

			emisor = xml.at_xpath("//cfdi:Emisor")
			emisor['Nombre'] = @razon
			emisor['RegimenFiscal'] = @regimen_fiscal
			emisor['Rfc'] = @rfc

			receptor = xml.at_xpath("//cfdi:Receptor")
			receptor['Nombre'] = params.fetch(:receptor_razon, '')
			receptor['Rfc'] = params.fetch(:receptor_rfc, 'XAXX010101000')
			receptor['UsoCFDI'] = params.fetch(:uso_cfdi, 'G03')


			# impuestos = xml.at_xpath("//cfdi:Impuestos")
			# traslados = Nokogiri::XML::Node.new "cfdi:Traslados", xml


			puts '--- sw_fac time -----'
			puts time
			puts '--------'

			conceptos = xml.at_xpath("//cfdi:Conceptos")

			line_items = params[:line_items]

			suma_total = 0.00

			line_items.each do |line|
				
				valor_unitario = line[:valor_unitario].to_f
				cantidad = line[:cantidad].to_f
				total_line = cantidad * valor_unitario

				suma_total += total_line 

				## Creando y poblando CFDI:CONCEPTO
				child_concepto = Nokogiri::XML::Node.new "cfdi:Concepto", xml
				child_concepto['ClaveProdServ'] = line[:clave_prod_serv].to_s
				child_concepto['NoIdentificacion'] = line[:sku].to_s 
				child_concepto['ClaveUnidad'] = line[:clave_unidad].to_s
				child_concepto['Unidad'] = line[:unidad].to_s
				child_concepto['Descripcion'] = line[:descripcion].to_s
				child_concepto['Cantidad'] = cantidad.to_s
				child_concepto['ValorUnitario'] = valor_unitario.round(4).to_s
				child_concepto['Importe'] = total_line.round(4).to_s


				# Joining all up
				conceptos.add_child(child_concepto)
			

			end

			puts '------ Totales -----'
			puts "Subtotal = #{suma_total}"
			puts "Total = #{suma_total}"

			comprobante['Moneda'] = params.fetch(:moneda, 'MXN')
			comprobante['SubTotal'] = suma_total.round(2).to_s
			comprobante['Total'] = suma_total.round(2).to_s



			path = File.join(File.dirname(__FILE__), *%w[.. tmp])
			id = SecureRandom.hex

			FileUtils.mkdir_p(path) unless File.exist?(path)
				File.write("#{path}/tmp_#{id}.xml", xml.to_xml)
				xml_path = "#{path}/tmp_#{id}.xml"
			cadena_path = File.join(File.dirname(__FILE__), *%w[.. cadena cadena33.xslt])

			# puts File.read(cadena_path)
			File.write("#{path}/pem_#{id}.pem", @pem)
			key_pem_url = "#{path}/pem_#{id}.pem"
			sello = %x[xsltproc #{cadena_path} #{xml_path} | openssl dgst -sha256 -sign #{key_pem_url} | openssl enc -base64 -A]
			comprobante['Sello'] = sello

			File.delete("#{xml_path}")
			File.delete("#{key_pem_url}")

			puts '---- SW GEM comprobante sin timbrar ------'
			puts xml.to_xml
			puts '-------------------------'

			base64_xml = Base64.encode64(xml.to_xml)
			request = Net::HTTP::Post.new(uri)
			request.basic_auth(token, "")
			request.content_type = "application/json"
			request["cache-control"] = 'no-cache'
			request.body = JSON.dump({
				"credentials" => {
					"id" => params.fetch(:folio).to_s,
					"token" => token
				},
				"issuer" => {
					"rfc" => emisor['Rfc']
				},
				"document" => {
					"ref-id": params.fetch(:folio).to_s,
					"certificate-number": comprobante['NoCertificado'],
					"section": "all",
					"format": "xml",
					"template": "letter",
					"type": "application/xml",
					"content": base64_xml
				}
			})

			req_options = {
				use_ssl: false,
			}

			json_response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
				http.request(request)
			end

			puts "-- SW API reponse..."
			puts "-- Response code: #{json_response.code} --"
			puts "-- Response body: #{json_response.body} --"
			puts "-- Response message: #{json_response.message} --"

			response = JSON.parse(json_response.body)

			if json_response.code == '200'
				decoded_xml = Nokogiri::XML(Base64.decode64(response['content']))
				timbre = decoded_xml.at_xpath("//cfdi:Complemento").children.first

				response = {
					status: 200,
					message_error: '',
					xml: decoded_xml.to_xml,
					uuid: response['uuid'],
					fecha_timbrado: timbre['FechaTimbrado'],
					sello_cfd: timbre['SelloCFD'],
					sello_sat: timbre['SelloSAT'],
					no_certificado_sat: timbre['NoCertificadoSAT'],
				}

				return response
			else

				response ={
					status: json_response.code,
					message_error: "Error message: #{json_response.message}, #{response['message']} #{response['error_details']}",
					xml: '',
					uuid: '',
					fecha_timbrado: '',
					sello_cfd: '',
					sello_sat: '',
					no_certificado_sat: '',
				}

				return response
			end

			
		end
		

	end

end