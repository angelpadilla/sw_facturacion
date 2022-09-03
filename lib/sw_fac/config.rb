module SwFac
  class Config
    attr_accessor :production_token, :dev_token, :doc_cer_path, :doc_key_path
    attr_reader :pem, :serial, :cadena, :key_pass, :pem_cadena

    def initialize(production_token, development_token, rfc, razon, regimen, doc_key_path, key_pass, doc_cer_path, production=false)
		  puts "---- SwFacturacion:config:initialize"

      @production_token = production_token.to_s
      @dev_token = development_token.to_s
      @rfc = rfc.to_s
      @razon = razon.to_s
      @regimen_fiscal = regimen
      @doc_key_path = doc_key_path.to_s
      @key_pass = key_pass.to_s
      @doc_cer_path = doc_cer_path
      @production = production

      key_to_pem 
      serial_number 
      cer_cadena

    end

    def key_to_pem
      puts "---- SwFacturacion:config:key_to_pem"

      puts "-- 1"
      @pem = %x[openssl pkcs8 -inform DER -in #{@doc_key_path} -passin pass:#{@key_pass}]
      # @pem = %x[openssl rsa -inform DER -in #{@doc_key_path} -passin pass:#{@key_pass}]
      puts "-- 2"
      @pem_cadena = @pem.clone
      @pem_cadena.slice!("-----BEGIN PRIVATE KEY-----")
      @pem_cadena.slice!("-----END PRIVATE KEY-----")
      @pem_cadena.delete!("\n")
    end

    def serial_number
      puts "---- SwFacturacion:config:serial_number"

      response = %x[openssl x509 -inform DER -in #{@doc_cer_path} -noout -serial]
      d_begin = response.index(/\d/)
      number = (response[d_begin..-1]).chomp
      final_serial = ""

      number.each_char.with_index do |s, index|
        if (index + 1).even?
          final_serial << s
        end
      end

      @serial = final_serial
      
    end


    def cer_cadena
      puts "---- SwFacturacion:config:cer_cadena"

      file = File.read(@doc_cer_path)
      text_certificate = OpenSSL::X509::Certificate.new(file)
      cert_string = text_certificate.to_s
      cert_string.slice!("-----BEGIN CERTIFICATE-----")
      cert_string.slice!("-----END CERTIFICATE-----")
      cert_string.delete!("\n")
      @cadena = cert_string

    end
    
  end


  UrlProduction = "http://services.sw.com.mx/"
  UrlDev = "http://services.test.sw.com.mx/"

  DocBase = %(<?xml version="1.0" encoding="utf-8"?><cfdi:Comprobante xsi:schemaLocation="http://www.sat.gob.mx/cfd/3 http://www.sat.gob.mx/sitio_internet/cfd/3/cfdv33.xsd" Version="3.3" xmlns:cfdi="http://www.sat.gob.mx/cfd/3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><cfdi:Emisor />
  <cfdi:Receptor /><cfdi:Conceptos></cfdi:Conceptos>
  <cfdi:Impuestos></cfdi:Impuestos></cfdi:Comprobante>)

  DocBaseCero = %(<?xml version="1.0" encoding="utf-8"?><cfdi:Comprobante xsi:schemaLocation="http://www.sat.gob.mx/cfd/3 http://www.sat.gob.mx/sitio_internet/cfd/3/cfdv33.xsd" Version="3.3" xmlns:cfdi="http://www.sat.gob.mx/cfd/3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><cfdi:Emisor />
  <cfdi:Receptor /><cfdi:Conceptos></cfdi:Conceptos></cfdi:Comprobante>)

  Doc_concepto = %(<cfdi:Concepto ClaveProdServ="25172504" NoIdentificacion="COST37125R17" Cantidad="1" ClaveUnidad="H87" Unidad="Pieza" Descripcion="Producto de prueba" ValorUnitario="1000.00" Importe="1000.00"><cfdi:Impuestos><cfdi:Traslados><cfdi:Traslado Base="1000.00" Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="160.00" /></cfdi:Traslados></cfdi:Impuestos></cfdi:Concepto>)


end