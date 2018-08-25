
module SwFac
  class Facturacion < Config

  	# def initialize()
  		
  	# end

  	def timbra_doc(params={})
  		### sample params
  		# 
  		# params = {
  		# 	total: 100.00,
  		# 	subtotal: 86.00,
  		# 	descuento: 0.00,
  		# 	tax: 16.00,
  		# 	moneda: 'MXN',
  		# 	series: 'FA',
  		# 	folio: '003',
  		# 	forma_pago: '',
  		# 	metodo_pago: 'PUE',
  		# 	cp: '47180',
  		# 	receptor_razon: 'Car zone',
  		# 	receptor_rfc: '',
  		# 	uso_cfdi: 'G03',
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
	   #  			# Optional parameters
	   #  			# tipo_impuesto: '002'
  		# 		},
  		# 	]

  		# }


  		uri = @production ? SwFac::UrlProduction : SwFac::UrlDev 
  		token = @production ? @production_token : @dev_token
  		time = Time.now

    	xml = Nokogiri::XML(SwFac::DocBase)
	    comprobante = xml.at_xpath("//cfdi:Comprobante")
	    comprobante['Descuento'] = params.fetch(:descuento, '').to_s
	    comprobante['SubTotal'] = params.fetch(:subtotal, '').to_s
	    comprobante['Total'] = params.fetch(:total, '').to_s
	    comprobante['Moneda'] = params.fetch(:moneda, 'MXN')
	    comprobante['TipoCambio'] = '1'
	    comprobante['TipoDeComprobante'] = 'I'
	    comprobante['Serie'] = params.fetch(:series, 'FA').to_s
	    comprobante['Folio'] = params.fetch(:folio).to_s
	    comprobante['Fecha'] = time.strftime("%Y-%m-%dT%H:%M:%S")
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

	    impuestos = xml.at_xpath("//cfdi:Impuestos")
	    impuestos['TotalImpuestosTrasladados'] = params.fetch(:tax, 0.00).to_s
	    traslado = xml.at_xpath("//cfdi:Traslado")
	    traslado['Importe'] = params.fetch(:tax, 0.00).to_s

	    conceptos = xml.at_xpath("//cfdi:Conceptos")

	    line_items = params[:line_items]

	    line_items.each do |line|

	      if line[:tax_included] == true
	      	# precio neto
	      	total_line = ((line[:cantidad]).to_f * (line[:valor_unitario]).to_f) - (line[:descuento]).to_f
	      	importe_iva = 0.1600 * total_line 
	      else
	      	total_line = (((line[:cantidad]).to_f * (line[:valor_unitario]).to_f) - (line[:descuento]).to_f) * 1.16
	      	importe_iva = 0.1600 * total_line 

	      end

	      child_concepto = Nokogiri::XML::Node.new "cfdi:Concepto", xml
	      child_concepto['ClaveProdServ'] = line[:clave_prod_serv].to_s
	      child_concepto['NoIdentificacion'] = line[:sku].to_s 
	      child_concepto['Cantidad'] = line[:cantidad].to_s
	      child_concepto['ClaveUnidad'] = line[:clave_unidad].to_s
	      child_concepto['Unidad'] = line[:unidad].to_s
	      child_concepto['Descripcion'] = line[:descripcion].to_s
	      child_concepto['ValorUnitario'] = (line[:valor_unitario]).round(6).to_s
	      child_concepto['Importe'] = total_line.round(6).to_s
	      child_concepto['Descuento'] = (line[:descuento]).round(6).to_s

	      child_impuestos = Nokogiri::XML::Node.new "cfdi:Impuestos", xml
	      child_traslados = Nokogiri::XML::Node.new "cfdi:Traslados", xml
	      child_traslado = Nokogiri::XML::Node.new "cfdi:Traslado", xml
	      child_traslado['Base'] = total_line.round(6).to_s
	      child_traslado['Impuesto'] = line.fetch(:tipo_impuesto, '002')
	      child_traslado['TipoFactor'] = "Tasa"
	      child_traslado['TasaOCuota'] = '0.160000'
	      child_traslado['Importe'] = importe_iva.round(6).to_s
	    
	      # Joining all up
	      child_traslados.add_child(child_traslado)
	      child_impuestos.add_child(child_traslados)
	      child_concepto.add_child(child_impuestos)

	      conceptos.add_child(child_concepto)

	    end


	    puts xml.to_xml

      path = "../tmp"
	    id = SecureRandom.hex

    	FileUtils.mkdir_p(path) unless File.exist?(path)
			File.write("#{path}/tmp_#{id}.xml", xml.to_xml)
	    cadena_url = "../../cadena"

	    puts cadenaaa = File.join(File.dirname(__FILE__), *%w[lib cadena])
	    p File.read("#{cadenaaa}/cadena33.xslt")
	    puts File.exist?(cadenaaa)
      
	  #   key_pem_url = "#{Rails.root.to_s}/public#{File.dirname(@sale.company.key_pem.url)}/#{@sale.company.key_pem_file_name}"

	  #   sello = %x[xsltproc #{cadena_url} app/controllers/admin/tmp/tmp_#{@sale.id}.xml | openssl dgst -sha256 -sign #{key_pem_url} | openssl enc -base64 -A]
	  #   comprobante['Sello'] = sello
	  #   @sale.tax_sello_emisor = sello
	  #   File.delete("#{Rails.root.to_s}/app/controllers/admin/tmp/tmp_#{@sale.id}.xml")


  	end
  end
end