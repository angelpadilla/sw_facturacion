module SwFac
  class Config
    # attr_accessor :production_token, :dev_token
    attr_accessor :production_token, :dev_token, :doc_cer_path, :doc_key_path
    attr_reader :pem, :serial, :cadena

    def initialize(params = {})
      @rfc = params.fetch(:rfc, '')
      @razon = params.fetch(:razon, '')
      @production_token = params.fetch(:production_token, 'test')
      @dev_token = params.fetch(:development_token, '')

      @doc_key_path = params.fetch(:doc_key_path, '')
      @key_pass = params.fetch(:key_pass, '')

      @doc_cer_path = params.fetch(:doc_cer_path, '')
      @production = params.fetch(:production, false)

      if @doc_key_path.size > 0 and @key_pass.size > 0
        @pem = key_to_pem
      else
        @pem = ''
      end

      if @doc_cer_path.size > 0
        @serial = serial_number 
        @cadena = cer_cadena
      else
        @serial = '' 
        @cadena = ''
      end
      
    end

    def key_to_pem
      %x[openssl pkcs8 -inform DER -in #{@doc_key_path} -passin pass:#{@key_pass}]
    end

    def serial_number
      response = %x[openssl x509 -inform DER -in #{@doc_cer_path} -noout -serial]
      d_begin = response.index(/\d/)
      number = (response[d_begin..-1]).chomp
      final_serial = ""

      number.each_char do |s|
        unless (s == "3")
          final_serial << s
        end
      end
      return final_serial
    end


    def cer_cadena
      file = File.read(@doc_cer_path)
      text_certificate = OpenSSL::X509::Certificate.new(file)
      cert_string = text_certificate.to_s
      cert_string.slice!("-----BEGIN CERTIFICATE-----")
      cert_string.slice!("-----END CERTIFICATE-----")
      cert_string.delete!("\n")
      return cert_string
    end
    
  end


  UrlProduction = "http://services.test.sw.com.mx/"
  UrlDev = "http://services.test.sw.com.mx/"
  DocBase = %(<?xml version="1.0" encoding="utf-8"?><cfdi:Comprobante xsi:schemaLocation="http://www.sat.gob.mx/cfd/3 http://www.sat.gob.mx/sitio_internet/cfd/3/cfdv33.xsd" Version="3.3" xmlns:cfdi="http://www.sat.gob.mx/cfd/3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><cfdi:Emisor /><cfdi:Receptor /><cfdi:Conceptos></cfdi:Conceptos><cfdi:Impuestos><cfdi:Traslados><cfdi:Traslado Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" /></cfdi:Traslados></cfdi:Impuestos></cfdi:Comprobante>)
  Doc_concepto = %(<cfdi:Concepto ClaveProdServ="25172504" NoIdentificacion="COST37125R17" Cantidad="1" ClaveUnidad="H87" Unidad="Pieza" Descripcion="Producto de prueba" ValorUnitario="1000.00" Importe="1000.00"><cfdi:Impuestos><cfdi:Traslados><cfdi:Traslado Base="1000.00" Impuesto="002" TipoFactor="Tasa" TasaOCuota="0.160000" Importe="160.00" /></cfdi:Traslados></cfdi:Impuestos></cfdi:Concepto>)


end