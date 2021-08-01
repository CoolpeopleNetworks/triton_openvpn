data "triton_account" "main" {}

resource "tls_private_key" "openvpn" {
    algorithm = "RSA"
    rsa_bits  = "4096"
}

# Create the request to sign the cert with our CA
resource "tls_cert_request" "openvpn-req" {
    key_algorithm   = tls_private_key.openvpn.algorithm
    private_key_pem = tls_private_key.openvpn.private_key_pem

    dns_names = [
        "openvpn",
        "openvpn.local",
        "openvpn.service.${var.config.network.domain_name}",
    ]

    subject {
        common_name  = "openvpn.local"
        organization = var.config.organization.name
    }
}

resource "tls_locally_signed_cert" "openvpn" {
    cert_request_pem = tls_cert_request.openvpn-req.cert_request_pem

    ca_key_algorithm   = var.config.certificate_authority.algorithm
    ca_private_key_pem = var.config.certificate_authority.private_key_pem
    ca_cert_pem        = var.config.certificate_authority.certificate_pem

    validity_period_hours = 8760

    allowed_uses = [
        "cert_signing",
        "client_auth",
        "digital_signature",
        "key_encipherment",
        "server_auth",
    ]
}

data "triton_image" "os" {
    name = "base-64-lts"
    version = "20.4.0"
}

resource "triton_machine" "openvpn" {
    name = "openvpn"
    package = var.config.server_package

    image = data.triton_image.os.id

    cns {
        services = ["openvpn"]
    }

    networks = [
        data.triton_network.public.id,
        data.triton_network.private.id
    ]
}

resource "null_resource" "provision" {
    triggers = {
        instance_ids = "${triton_machine.openvpn.id}"
    }

    connection {
        host = triton_machine.openvpn.primaryip
    }

    provisioner "file" {
        destination = "/etc/ipf/ipnat.conf"
        content = templatefile("${path.module}/templates/ipnat.conf.tpl", {
            map_rule = "map * from 10.8.0.0/24 to any -> 0.0.0.0/32"
        })
    }

    provisioner "remote-exec" {
        inline = [
            # Disable ipfiltering in case it's enabled
            "svcadm disable ipfilter",

            # Enable IP forwarding" - configuration done above inside ipnat.conf
            "routeadm -ue ipv4-forwarding",

            # Enable NAT for packets from clients
            "svcadm enable ipfilter",

            # Install openvpn and generate dhparam key
            "pkgin -y update",
            "pkgin -y install easy-rsa openvpn",
            "svcadm disable openvpn",
            "openssl dhparam -out /opt/local/etc/openvpn/dh2048.pem 2048",

            # Initialize easyrsa and create ca
#            "easyrsa init-pki ",
        ]
    }

    provisioner "file" {
        destination = "/opt/local/etc/openvpn/openvpn.conf"
        content = templatefile("${path.module}/templates/openvpn.conf.tpl", {
            domain = "inst.${data.triton_account.main.id}.${var.config.network.cns_suffix}"
        })
    }

    provisioner "file" {
        destination = "/opt/local/etc/openvpn/ca.crt"
        content = var.config.certificate_authority.certificate_pem
    }

    provisioner "file" {
        destination = "/opt/local/etc/openvpn/server.crt"
        content = tls_locally_signed_cert.openvpn.cert_pem
    }

    provisioner "file" {
        destination = "/opt/local/etc/openvpn/server.key"
        content = tls_private_key.openvpn.private_key_pem
    }

    provisioner "remote-exec" {
        inline = [
            "svcadm enable openvpn"
        ]
    }
}

output "primaryip" {
    value = triton_machine.openvpn.primaryip
}
