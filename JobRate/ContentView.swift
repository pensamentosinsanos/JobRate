//
//  ContentView.swift
//  JobRate
//

import SwiftUI
import Combine
import Security
import MapKit
import CoreLocation
import PhotosUI
import UIKit


// MARK: - CONTA

struct ContaLocal: Codable, Identifiable {
    var email: String

    var id: String {
        email
    }
}


// MARK: - LOCAL

struct LocalEncontrado: Identifiable {

    let id: String
    let nome: String
    let endereco: String
    let latitude: Double
    let longitude: Double

    init(mapItem: MKMapItem) {

        let coordenada = mapItem.placemark.coordinate

        nome = mapItem.name ?? "Local sem nome"
        latitude = coordenada.latitude
        longitude = coordenada.longitude

        endereco = LocalEncontrado.montarEndereco(
            placemark: mapItem.placemark
        )

        id = "\(nome.lowercased())-\(latitude)-\(longitude)"
    }

    init(localTrabalhado: LocalTrabalhado) {

        id = localTrabalhado.id
        nome = localTrabalhado.nome
        endereco = localTrabalhado.endereco
        latitude = localTrabalhado.latitude
        longitude = localTrabalhado.longitude
    }

    private static func montarEndereco(
        placemark: MKPlacemark
    ) -> String {

        var partes: [String] = []

        if let rua = placemark.thoroughfare {

            if let numero = placemark.subThoroughfare {
                partes.append("\(rua), \(numero)")
            } else {
                partes.append(rua)
            }
        }

        if let bairro = placemark.subLocality {
            partes.append(bairro)
        }

        if let cidade = placemark.locality {
            partes.append(cidade)
        }

        if let estado = placemark.administrativeArea {
            partes.append(estado)
        }

        if partes.isEmpty {
            return placemark.title ?? "Endereço não disponível"
        }

        return partes.joined(separator: " • ")
    }
}


// MARK: - LOCAL ONDE TRABALHOU

struct LocalTrabalhado: Codable, Identifiable {

    let id: String
    let nome: String
    let endereco: String
    let latitude: Double
    let longitude: Double

    init(local: LocalEncontrado) {

        id = local.id
        nome = local.nome
        endereco = local.endereco
        latitude = local.latitude
        longitude = local.longitude
    }
}


// MARK: - AVALIAÇÃO

struct AvaliacaoLocal: Codable, Identifiable {

    let id: UUID
    let localID: String
    let localNome: String
    let emailAutor: String
    let estrelas: Int
    let comentario: String
    let categorias: [String]
    let data: Date
}


// MARK: - FILTRO

enum FiltroAvaliacao: String, CaseIterable, Identifiable {

    case todas = "Todas"
    case boas = "Boas"
    case ruins = "Ruins"

    var id: String {
        rawValue
    }
}


// MARK: - CORES DO PERFIL

enum CorPerfil: String, Codable, CaseIterable, Identifiable {

    case rosa
    case roxo
    case azul
    case verde
    case laranja

    var id: String {
        rawValue
    }

    var nome: String {

        switch self {

        case .rosa:
            return "Rosa"

        case .roxo:
            return "Roxo"

        case .azul:
            return "Azul"

        case .verde:
            return "Verde"

        case .laranja:
            return "Laranja"
        }
    }

    var cor: Color {

        switch self {

        case .rosa:
            return .pink

        case .roxo:
            return .purple

        case .azul:
            return .blue

        case .verde:
            return .green

        case .laranja:
            return .orange
        }
    }
}


// MARK: - PERFIL

struct PerfilUsuario: Codable, Identifiable {

    var email: String

    // Optional para contas antigas continuarem funcionando
    var apelido: String?

    var corPerfil: CorPerfil
    var fotoData: Data?
    var locaisTrabalhados: [LocalTrabalhado]

    var id: String {
        email
    }

    var nomeExibicao: String {

        let nome = apelido?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        if nome.isEmpty {
            return "Usuário JobRate"
        }

        return nome
    }
}


// MARK: - STORE DE PERFIL

class PerfilStore: ObservableObject {

    @Published private(set) var perfis: [PerfilUsuario] = []

    private let chave = "jobrate.perfis"

    init() {
        carregar()
    }

    func perfil(
        email: String
    ) -> PerfilUsuario {

        if let perfil = perfis.first(
            where: {
                $0.email == email
            }
        ) {

            return perfil
        }

        return PerfilUsuario(
            email: email,
            apelido: nil,
            corPerfil: .rosa,
            fotoData: nil,
            locaisTrabalhados: []
        )
    }

    func atualizarApelido(
        email: String,
        apelido: String
    ) {

        let apelidoLimpo = apelido
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !apelidoLimpo.isEmpty else {
            return
        }

        let indice = garantirPerfil(
            email: email
        )

        perfis[indice].apelido = apelidoLimpo

        salvar()
    }

    func atualizarCor(
        email: String,
        cor: CorPerfil
    ) {

        let indice = garantirPerfil(
            email: email
        )

        perfis[indice].corPerfil = cor

        salvar()
    }

    func atualizarFoto(
        email: String,
        dados: Data
    ) {

        guard let fotoTratada = tratarImagem(
            dados
        ) else {
            return
        }

        let indice = garantirPerfil(
            email: email
        )

        perfis[indice].fotoData = fotoTratada

        salvar()
    }

    func removerFoto(
        email: String
    ) {

        let indice = garantirPerfil(
            email: email
        )

        perfis[indice].fotoData = nil

        salvar()
    }

    func temLocal(
        email: String,
        localID: String
    ) -> Bool {

        let perfil = perfil(
            email: email
        )

        return perfil
            .locaisTrabalhados
            .contains {
                $0.id == localID
            }
    }

    func alternarLocal(
        email: String,
        local: LocalEncontrado
    ) {

        let indice = garantirPerfil(
            email: email
        )

        if let localIndex = perfis[indice]
            .locaisTrabalhados
            .firstIndex(
                where: {
                    $0.id == local.id
                }
            ) {

            perfis[indice]
                .locaisTrabalhados
                .remove(
                    at: localIndex
                )

        } else {

            perfis[indice]
                .locaisTrabalhados
                .append(
                    LocalTrabalhado(
                        local: local
                    )
                )
        }

        salvar()
    }

    private func garantirPerfil(
        email: String
    ) -> Int {

        if let indice = perfis.firstIndex(
            where: {
                $0.email == email
            }
        ) {

            return indice
        }

        perfis.append(
            PerfilUsuario(
                email: email,
                apelido: nil,
                corPerfil: .rosa,
                fotoData: nil,
                locaisTrabalhados: []
            )
        )

        return perfis.count - 1
    }

    private func salvar() {

        if let dados = try? JSONEncoder().encode(
            perfis
        ) {

            UserDefaults.standard.set(
                dados,
                forKey: chave
            )
        }
    }

    private func carregar() {

        guard
            let dados = UserDefaults.standard.data(
                forKey: chave
            ),

            let salvos = try? JSONDecoder().decode(
                [PerfilUsuario].self,
                from: dados
            )

        else {
            return
        }

        perfis = salvos
    }

    private func tratarImagem(
        _ dados: Data
    ) -> Data? {

        guard let imagem = UIImage(
            data: dados
        ) else {
            return nil
        }

        let maximo: CGFloat = 600

        let maiorLado = max(
            imagem.size.width,
            imagem.size.height
        )

        let escala = min(
            1,
            maximo / maiorLado
        )

        let tamanho = CGSize(
            width: imagem.size.width * escala,
            height: imagem.size.height * escala
        )

        let renderer = UIGraphicsImageRenderer(
            size: tamanho
        )

        let redimensionada = renderer.image {
            _ in

            imagem.draw(
                in: CGRect(
                    origin: .zero,
                    size: tamanho
                )
            )
        }

        return redimensionada.jpegData(
            compressionQuality: 0.75
        )
    }
}


// MARK: - AVATAR

struct AvatarPerfilView: View {

    let perfil: PerfilUsuario

    var tamanho: CGFloat = 48

    var body: some View {

        ZStack {

            Circle()
                .fill(
                    perfil
                        .corPerfil
                        .cor
                        .opacity(0.15)
                )

            if let dados = perfil.fotoData,
               let imagem = UIImage(
                data: dados
               ) {

                Image(
                    uiImage: imagem
                )
                .resizable()
                .scaledToFill()
                .frame(
                    width: tamanho,
                    height: tamanho
                )
                .clipShape(
                    Circle()
                )

            } else {

                Image(
                    systemName: "person.fill"
                )
                .font(
                    .system(
                        size: tamanho * 0.43
                    )
                )
                .foregroundColor(
                    perfil
                        .corPerfil
                        .cor
                )
            }
        }
        .frame(
            width: tamanho,
            height: tamanho
        )
        .overlay(

            Circle()
                .stroke(
                    perfil
                        .corPerfil
                        .cor,
                    lineWidth: max(
                        2,
                        tamanho * 0.055
                    )
                )
        )
        .clipShape(
            Circle()
        )
    }
}


// MARK: - AUTENTICAÇÃO

class LocalAuthStore: ObservableObject {

    @Published var usuarioAtual: ContaLocal?
    @Published var mensagemErro = ""
    @Published var mostrarBoasVindas = false

    private var contas: [ContaLocal] = []

    private let contasKey = "jobrate.contas"
    private let sessaoKey = "jobrate.sessao"
    private let servico = "jobrate.senhas"

    init() {
        carregarContas()
        recuperarSessao()
    }

    private func carregarContas() {

        if let dados = UserDefaults.standard.data(
            forKey: contasKey
        ),
           let contasSalvas = try? JSONDecoder().decode(
            [ContaLocal].self,
            from: dados
           ) {

            contas = contasSalvas
        }
    }

    private func recuperarSessao() {

        if let email = UserDefaults.standard.string(
            forKey: sessaoKey
        ),
           let conta = contas.first(
            where: {
                $0.email == email
            }
           ) {

            usuarioAtual = conta
            mostrarBoasVindas = false
        }
    }

    func cadastrar(
        email: String,
        senha: String,
        confirmarSenha: String
    ) -> Bool {

        mensagemErro = ""

        let emailLimpo = email
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        if emailLimpo.isEmpty ||
            senha.isEmpty ||
            confirmarSenha.isEmpty {

            mensagemErro = "Preencha todos os campos."

            return false
        }

        let partesEmail = emailLimpo.split(
            separator: "@",
            omittingEmptySubsequences: false
        )

        if partesEmail.count != 2 ||
            partesEmail[0].isEmpty ||
            partesEmail[1].isEmpty ||
            !partesEmail[1].contains(".") {

            mensagemErro = "Digite um e-mail válido."

            return false
        }

        if senha.count < 8 {

            mensagemErro =
                "A senha precisa ter pelo menos 8 caracteres."

            return false
        }

        if senha != confirmarSenha {

            mensagemErro =
                "As senhas não são iguais."

            return false
        }

        if contas.contains(
            where: {
                $0.email == emailLimpo
            }
        ) {

            mensagemErro =
                "Este e-mail já está cadastrado."

            return false
        }

        let novaConta = ContaLocal(
            email: emailLimpo
        )

        let novasContas = contas + [
            novaConta
        ]

        guard let dados = try? JSONEncoder().encode(
            novasContas
        ) else {

            mensagemErro =
                "Não foi possível criar a conta."

            return false
        }

        if !salvarSenha(
            senha,
            email: emailLimpo
        ) {

            mensagemErro =
                "Não foi possível salvar a senha."

            return false
        }

        UserDefaults.standard.set(
            dados,
            forKey: contasKey
        )

        contas = novasContas

        iniciarSessao(
            conta: novaConta
        )

        return true
    }

    func entrar(
        email: String,
        senha: String
    ) {

        mensagemErro = ""

        let emailLimpo = email
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        if emailLimpo.isEmpty ||
            senha.isEmpty {

            mensagemErro =
                "Preencha todos os campos."

            return
        }

        guard let conta = contas.first(
            where: {
                $0.email == emailLimpo
            }
        ) else {

            mensagemErro =
                "E-mail ou senha incorretos."

            return
        }

        guard let senhaSalva = recuperarSenha(
            email: emailLimpo
        ) else {

            mensagemErro =
                "Não foi possível acessar esta conta."

            return
        }

        if senha == senhaSalva {

            iniciarSessao(
                conta: conta
            )

        } else {

            mensagemErro =
                "E-mail ou senha incorretos."
        }
    }

    private func iniciarSessao(
        conta: ContaLocal
    ) {

        mensagemErro = ""

        usuarioAtual = conta

        mostrarBoasVindas = true

        UserDefaults.standard.set(
            conta.email,
            forKey: sessaoKey
        )
    }

    func continuarParaApp() {

        mostrarBoasVindas = false
    }

    func sair() {

        mensagemErro = ""

        usuarioAtual = nil

        mostrarBoasVindas = false

        UserDefaults.standard.removeObject(
            forKey: sessaoKey
        )
    }

    private func salvarSenha(
        _ senha: String,
        email: String
    ) -> Bool {

        guard let dados = senha.data(
            using: .utf8
        ) else {

            return false
        }

        let consulta: [String: Any] = [

            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                servico,

            kSecAttrAccount as String:
                email
        ]

        var item = consulta

        item[
            kSecValueData as String
        ] = dados

        item[
            kSecAttrAccessible as String
        ] =
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let resultado = SecItemAdd(
            item as CFDictionary,
            nil
        )

        if resultado == errSecSuccess {

            return true
        }

        if resultado == errSecDuplicateItem {

            let novosDados: [String: Any] = [

                kSecValueData as String:
                    dados
            ]

            return SecItemUpdate(
                consulta as CFDictionary,
                novosDados as CFDictionary
            ) == errSecSuccess
        }

        return false
    }

    private func recuperarSenha(
        email: String
    ) -> String? {

        let consulta: [String: Any] = [

            kSecClass as String:
                kSecClassGenericPassword,

            kSecAttrService as String:
                servico,

            kSecAttrAccount as String:
                email,

            kSecReturnData as String:
                true,

            kSecMatchLimit as String:
                kSecMatchLimitOne
        ]

        var resultado: CFTypeRef?

        let status = SecItemCopyMatching(
            consulta as CFDictionary,
            &resultado
        )

        guard
            status == errSecSuccess,
            let dados = resultado as? Data

        else {

            return nil
        }

        return String(
            data: dados,
            encoding: .utf8
        )
    }
}


// MARK: - LOCALIZAÇÃO

class LocalizacaoManager:
    NSObject,
    ObservableObject,
    CLLocationManagerDelegate {

    @Published var localizacaoAtual: CLLocation?
    @Published var mensagem = ""

    private let manager = CLLocationManager()

    override init() {

        super.init()

        manager.delegate = self

        manager.desiredAccuracy =
            kCLLocationAccuracyHundredMeters
    }

    func solicitarPermissao() {

        guard CLLocationManager
            .locationServicesEnabled()
        else {

            mensagem =
                "Os Serviços de Localização estão desativados."

            return
        }

        switch manager.authorizationStatus {

        case .notDetermined:

            manager.requestWhenInUseAuthorization()

        case .authorizedAlways,
             .authorizedWhenInUse:

            atualizarLocalizacao()

        case .denied:

            mensagem =
                "Permita o acesso à localização nos Ajustes."

        case .restricted:

            mensagem =
                "O acesso à localização está restrito."

        @unknown default:

            break
        }
    }

    func atualizarLocalizacao() {

        if manager.authorizationStatus ==
            .authorizedWhenInUse ||

            manager.authorizationStatus ==
            .authorizedAlways {

            mensagem = ""

            manager.requestLocation()

        } else {

            solicitarPermissao()
        }
    }

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {

        switch manager.authorizationStatus {

        case .authorizedAlways,
             .authorizedWhenInUse:

            manager.requestLocation()

        case .denied:

            DispatchQueue.main.async {

                self.mensagem =
                    "Você ainda pode pesquisar empresas sem compartilhar sua localização."
            }

        default:

            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {

        guard let local = locations.last else {
            return
        }

        DispatchQueue.main.async {

            self.localizacaoAtual = local

            self.mensagem = ""
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {

        if let erro = error as? CLError,
           erro.code == .locationUnknown {

            return
        }

        DispatchQueue.main.async {

            self.mensagem =
                "Não foi possível descobrir sua localização."
        }
    }
}


// MARK: - STORE DAS AVALIAÇÕES

class AvaliacoesStore: ObservableObject {

    @Published var avaliacoes: [AvaliacaoLocal] = []

    private let chave =
        "jobrate.avaliacoes"

    init() {
        carregar()
    }

    func adicionar(
        local: LocalEncontrado,
        email: String,
        estrelas: Int,
        comentario: String,
        categorias: [String]
    ) {

        let avaliacao = AvaliacaoLocal(

            id: UUID(),

            localID: local.id,

            localNome: local.nome,

            emailAutor: email,

            estrelas: estrelas,

            comentario: comentario,

            categorias: categorias,

            data: Date()
        )

        avaliacoes.append(
            avaliacao
        )

        salvar()
    }

    func avaliacoes(
        do localID: String
    ) -> [AvaliacaoLocal] {

        avaliacoes
            .filter {
                $0.localID == localID
            }
            .sorted {
                $0.data > $1.data
            }
    }

    func avaliacoes(
        doUsuario email: String
    ) -> [AvaliacaoLocal] {

        avaliacoes
            .filter {
                $0.emailAutor == email
            }
            .sorted {
                $0.data > $1.data
            }
    }

    private func salvar() {

        if let dados = try? JSONEncoder().encode(
            avaliacoes
        ) {

            UserDefaults.standard.set(
                dados,
                forKey: chave
            )
        }
    }

    private func carregar() {

        guard
            let dados = UserDefaults.standard.data(
                forKey: chave
            ),

            let salvas = try? JSONDecoder().decode(
                [AvaliacaoLocal].self,
                from: dados
            )

        else {

            return
        }

        avaliacoes = salvas
    }
}


// MARK: - PESQUISA MAPKIT

class PesquisaLocaisModel:
    NSObject,
    ObservableObject,
    MKLocalSearchCompleterDelegate {

    @Published var texto = "" {

        didSet {
            atualizarPesquisa()
        }
    }

    @Published var sugestoes:
        [MKLocalSearchCompletion] = []

    @Published var carregando = false

    @Published var mensagemErro = ""

    private let completer =
        MKLocalSearchCompleter()

    private var buscaAtual:
        MKLocalSearch?

    private var regiaoPesquisa =
        MKCoordinateRegion(

            center:
                CLLocationCoordinate2D(
                    latitude: -14.235,
                    longitude: -51.9253
                ),

            span:
                MKCoordinateSpan(
                    latitudeDelta: 40,
                    longitudeDelta: 40
                )
        )

    override init() {

        super.init()

        completer.delegate = self

        completer.resultTypes = [
            .pointOfInterest,
            .address
        ]

        completer.region =
            regiaoPesquisa
    }

    func atualizarRegiao(
        com coordenada: CLLocationCoordinate2D
    ) {

        regiaoPesquisa =
            MKCoordinateRegion(

                center: coordenada,

                span:
                    MKCoordinateSpan(
                        latitudeDelta: 0.5,
                        longitudeDelta: 0.5
                    )
            )

        completer.region =
            regiaoPesquisa
    }

    private func atualizarPesquisa() {

        let textoLimpo = texto
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        mensagemErro = ""

        if textoLimpo.count < 2 {

            sugestoes = []

            completer.queryFragment = ""

            return
        }

        completer.queryFragment =
            textoLimpo
    }

    func limpar() {

        texto = ""

        sugestoes = []

        mensagemErro = ""

        completer.cancel()

        buscaAtual?.cancel()
    }

    func completerDidUpdateResults(
        _ completer: MKLocalSearchCompleter
    ) {

        DispatchQueue.main.async {

            self.sugestoes =
                Array(
                    completer
                        .results
                        .prefix(7)
                )
        }
    }

    func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: Error
    ) {

        DispatchQueue.main.async {

            self.mensagemErro =
                "Não foi possível buscar locais."
        }
    }

    func resolver(
        _ sugestao: MKLocalSearchCompletion,
        conclusao:
            @escaping (LocalEncontrado?) -> Void
    ) {

        carregando = true

        mensagemErro = ""

        buscaAtual?.cancel()

        let request =
            MKLocalSearch.Request(
                completion: sugestao
            )

        request.region =
            regiaoPesquisa

        request.resultTypes = [
            .pointOfInterest,
            .address
        ]

        let busca =
            MKLocalSearch(
                request: request
            )

        buscaAtual = busca

        busca.start {
            response,
            error in

            DispatchQueue.main.async {

                self.carregando = false

                if error != nil {

                    self.mensagemErro =
                        "Não foi possível carregar este local."

                    conclusao(nil)

                    return
                }

                guard
                    let mapItem =
                        response?
                            .mapItems
                            .first

                else {

                    self.mensagemErro =
                        "Nenhum local encontrado."

                    conclusao(nil)

                    return
                }

                let local =
                    LocalEncontrado(
                        mapItem: mapItem
                    )

                self.texto =
                    local.nome

                self.sugestoes = []

                conclusao(
                    local
                )
            }
        }
    }

    func pesquisarTextoDigitado(
        conclusao:
            @escaping (LocalEncontrado?) -> Void
    ) {

        let termo = texto
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard termo.count >= 2 else {

            mensagemErro =
                "Digite o nome de uma empresa ou local."

            return
        }

        carregando = true

        mensagemErro = ""

        buscaAtual?.cancel()

        let request =
            MKLocalSearch.Request()

        request.naturalLanguageQuery =
            termo

        request.region =
            regiaoPesquisa

        request.resultTypes = [
            .pointOfInterest,
            .address
        ]

        let busca =
            MKLocalSearch(
                request: request
            )

        buscaAtual = busca

        busca.start {
            response,
            error in

            DispatchQueue.main.async {

                self.carregando = false

                if error != nil {

                    self.mensagemErro =
                        "Não foi possível fazer a pesquisa."

                    conclusao(nil)

                    return
                }

                guard
                    let mapItem =
                        response?
                            .mapItems
                            .first

                else {

                    self.mensagemErro =
                        "Nenhum local encontrado."

                    conclusao(nil)

                    return
                }

                let local =
                    LocalEncontrado(
                        mapItem: mapItem
                    )

                self.sugestoes = []

                conclusao(
                    local
                )
            }
        }
    }
}


// MARK: - MAPA PRINCIPAL

struct MapaPrincipalView:
    UIViewRepresentable {

    let localizacaoUsuario:
        CLLocation?

    let localSelecionado:
        LocalEncontrado?

    let centralizarToken:
        Int

    func makeCoordinator() -> Coordinator {

        Coordinator()
    }

    func makeUIView(
        context: Context
    ) -> MKMapView {

        let mapa =
            MKMapView()

        mapa.mapType =
            .mutedStandard

        mapa.showsUserLocation =
            true

        mapa.showsCompass =
            true

        mapa.isZoomEnabled =
            true

        mapa.isScrollEnabled =
            true

        mapa.isRotateEnabled =
            true

        return mapa
    }

    func updateUIView(
        _ mapa: MKMapView,
        context: Context
    ) {

        mapa.showsUserLocation =
            true

        mapa.removeAnnotations(

            mapa.annotations.filter {

                !($0 is MKUserLocation)
            }
        )

        if let local =
            localSelecionado {

            let coordenada =
                CLLocationCoordinate2D(

                    latitude:
                        local.latitude,

                    longitude:
                        local.longitude
                )

            let marcador =
                MKPointAnnotation()

            marcador.coordinate =
                coordenada

            marcador.title =
                local.nome

            mapa.addAnnotation(
                marcador
            )

            if context
                .coordinator
                .ultimoLocalID != local.id {

                context
                    .coordinator
                    .ultimoLocalID =
                    local.id

                mapa.setRegion(

                    MKCoordinateRegion(

                        center: coordenada,

                        span:
                            MKCoordinateSpan(
                                latitudeDelta: 0.02,
                                longitudeDelta: 0.02
                            )
                    ),

                    animated: true
                )
            }

            return
        }

        if let localizacao =
            localizacaoUsuario {

            if !context
                .coordinator
                .jaCentralizou ||

                context
                .coordinator
                .ultimoToken != centralizarToken {

                context
                    .coordinator
                    .jaCentralizou = true

                context
                    .coordinator
                    .ultimoToken =
                    centralizarToken

                context
                    .coordinator
                    .ultimoLocalID = nil

                mapa.setRegion(

                    MKCoordinateRegion(

                        center:
                            localizacao
                                .coordinate,

                        span:
                            MKCoordinateSpan(
                                latitudeDelta: 0.025,
                                longitudeDelta: 0.025
                            )
                    ),

                    animated: true
                )
            }
        }
    }

    class Coordinator {

        var jaCentralizou = false
        var ultimoToken = 0
        var ultimoLocalID: String?
    }
}


// MARK: - MAPA DO LOCAL

struct AppleMapLocalView:
    UIViewRepresentable {

    let local: LocalEncontrado

    func makeUIView(
        context: Context
    ) -> MKMapView {

        let mapa =
            MKMapView()

        mapa.isZoomEnabled = true
        mapa.isScrollEnabled = true

        return mapa
    }

    func updateUIView(
        _ mapa: MKMapView,
        context: Context
    ) {

        let coordenada =
            CLLocationCoordinate2D(

                latitude:
                    local.latitude,

                longitude:
                    local.longitude
            )

        mapa.removeAnnotations(
            mapa.annotations
        )

        let marcador =
            MKPointAnnotation()

        marcador.coordinate =
            coordenada

        marcador.title =
            local.nome

        mapa.addAnnotation(
            marcador
        )

        mapa.setRegion(

            MKCoordinateRegion(

                center: coordenada,

                span:
                    MKCoordinateSpan(
                        latitudeDelta: 0.012,
                        longitudeDelta: 0.012
                    )
            ),

            animated: true
        )
    }
}


// MARK: - FUNDO LOGIN

struct FundoCircular<
    Conteudo: View
>: View {

    let conteudo: Conteudo

    init(
        @ViewBuilder
        conteudo:
            () -> Conteudo
    ) {

        self.conteudo =
            conteudo()
    }

    var body: some View {

        ZStack {

            Color.pink
                .ignoresSafeArea()

            GeometryReader {
                tela in

                let largura =
                    tela.size.width

                let altura =
                    tela.size.height

                let larguraFormulario =
                    min(
                        largura - 54,
                        340
                    )

                let circulo =
                    max(
                        largura * 1.42,
                        540
                    )

                ZStack {

                    Circle()
                        .fill(
                            Color.white
                                .opacity(0.22)
                        )
                        .frame(
                            width:
                                circulo + 35,
                            height:
                                circulo + 35
                        )

                    Circle()
                        .fill(
                            Color.white
                        )
                        .frame(
                            width:
                                circulo,
                            height:
                                circulo
                        )

                    ScrollView {

                        VStack {

                            conteudo
                                .frame(
                                    width:
                                        larguraFormulario
                                )
                        }
                        .frame(
                            width:
                                largura
                        )
                        .frame(
                            minHeight:
                                altura
                        )
                    }
                    .frame(
                        width:
                            largura,
                        height:
                            altura
                    )
                    .scrollDismissesKeyboard(
                        .interactively
                    )
                }
                .frame(
                    width:
                        largura,
                    height:
                        altura
                )
                .clipped()
            }
        }
    }
}


// MARK: - CONTENT VIEW

struct ContentView: View {

    @StateObject
    private var auth =
        LocalAuthStore()

    @StateObject
    private var avaliacoesStore =
        AvaliacoesStore()

    @StateObject
    private var perfilStore =
        PerfilStore()

    var body: some View {

        Group {

            if auth.usuarioAtual != nil {

                NavigationStack {

                    if auth.mostrarBoasVindas {

                        BoasVindasView(
                            auth: auth
                        )

                    } else {

                        HomeView(
                            auth: auth,
                            avaliacoesStore:
                                avaliacoesStore,
                            perfilStore:
                                perfilStore
                        )
                    }
                }

            } else {

                NavigationStack {

                    LoginView(
                        auth: auth,
                        perfilStore:
                            perfilStore
                    )
                }
            }
        }
    }
}


// MARK: - LOGIN

struct LoginView: View {

    @ObservedObject
    var auth:
        LocalAuthStore

    @ObservedObject
    var perfilStore:
        PerfilStore

    @State
    private var email = ""

    @State
    private var senha = ""

    var body: some View {

        FundoCircular {

            VStack(
                spacing: 15
            ) {

                Text(
                    "JobRate"
                )
                .font(
                    .system(
                        size: 38,
                        weight: .bold
                    )
                )
                .foregroundColor(
                    .pink
                )

                Text(
                    "Entre na sua conta"
                )
                .font(
                    .subheadline
                )
                .foregroundColor(
                    .gray
                )
                .padding(
                    .bottom,
                    20
                )

                TextField(
                    "E-mail",
                    text: $email
                )
                .keyboardType(
                    .emailAddress
                )
                .textContentType(
                    .emailAddress
                )
                .textInputAutocapitalization(
                    .never
                )
                .autocorrectionDisabled()
                .padding()
                .frame(
                    height: 52
                )
                .background(
                    Color.black
                        .opacity(0.05)
                )
                .cornerRadius(
                    12
                )

                SecureField(
                    "Senha",
                    text: $senha
                )
                .textContentType(
                    .password
                )
                .padding()
                .frame(
                    height: 52
                )
                .background(
                    Color.black
                        .opacity(0.05)
                )
                .cornerRadius(
                    12
                )

                if !auth
                    .mensagemErro
                    .isEmpty {

                    Text(
                        auth.mensagemErro
                    )
                    .font(
                        .caption
                    )
                    .foregroundColor(
                        .red
                    )
                }

                Button {

                    auth.entrar(
                        email: email,
                        senha: senha
                    )

                } label: {

                    Text(
                        "Entrar"
                    )
                    .bold()
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        height: 52
                    )
                }
                .foregroundColor(
                    .white
                )
                .background(
                    Color.pink
                )
                .cornerRadius(
                    12
                )

                NavigationLink {

                    CadastroView(
                        auth: auth,
                        perfilStore:
                            perfilStore
                    )

                } label: {

                    Text(
                        "Criar conta"
                    )
                    .bold()
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        height: 52
                    )
                }
                .foregroundColor(
                    .pink
                )
                .background(
                    Color.pink
                        .opacity(0.10)
                )
                .cornerRadius(
                    12
                )
            }
        }
        .toolbar(
            .hidden,
            for:
                .navigationBar
        )
    }
}


// MARK: - CADASTRO

struct CadastroView: View {

    @ObservedObject
    var auth:
        LocalAuthStore

    @ObservedObject
    var perfilStore:
        PerfilStore

    @State
    private var apelido = ""

    @State
    private var email = ""

    @State
    private var senha = ""

    @State
    private var confirmarSenha = ""

    @State
    private var erroApelido = ""

    var body: some View {

        FundoCircular {

            VStack(
                spacing: 15
            ) {

                Text(
                    "Criar conta"
                )
                .font(
                    .system(
                        size: 34,
                        weight: .bold
                    )
                )
                .foregroundColor(
                    .pink
                )

                Text(
                    "Cadastre-se no JobRate"
                )
                .foregroundColor(
                    .gray
                )
                .padding(
                    .bottom,
                    15
                )

                // APELIDO

                TextField(
                    "Apelido",
                    text: $apelido
                )
                .textInputAutocapitalization(
                    .words
                )
                .autocorrectionDisabled()
                .padding()
                .frame(
                    height: 52
                )
                .background(
                    Color.black
                        .opacity(0.05)
                )
                .cornerRadius(
                    12
                )

                // E-MAIL

                TextField(
                    "E-mail",
                    text: $email
                )
                .keyboardType(
                    .emailAddress
                )
                .textContentType(
                    .emailAddress
                )
                .textInputAutocapitalization(
                    .never
                )
                .autocorrectionDisabled()
                .padding()
                .frame(
                    height: 52
                )
                .background(
                    Color.black
                        .opacity(0.05)
                )
                .cornerRadius(
                    12
                )

                SecureField(
                    "Senha",
                    text: $senha
                )
                .textContentType(
                    .newPassword
                )
                .padding()
                .frame(
                    height: 52
                )
                .background(
                    Color.black
                        .opacity(0.05)
                )
                .cornerRadius(
                    12
                )

                SecureField(
                    "Confirmar senha",
                    text: $confirmarSenha
                )
                .textContentType(
                    .newPassword
                )
                .padding()
                .frame(
                    height: 52
                )
                .background(
                    Color.black
                        .opacity(0.05)
                )
                .cornerRadius(
                    12
                )

                if !erroApelido.isEmpty {

                    Text(
                        erroApelido
                    )
                    .font(
                        .caption
                    )
                    .foregroundColor(
                        .red
                    )
                }

                if !auth
                    .mensagemErro
                    .isEmpty {

                    Text(
                        auth.mensagemErro
                    )
                    .font(
                        .caption
                    )
                    .foregroundColor(
                        .red
                    )
                }

                Button {

                    criarConta()

                } label: {

                    Text(
                        "Cadastrar"
                    )
                    .bold()
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        height: 52
                    )
                }
                .foregroundColor(
                    .white
                )
                .background(
                    Color.pink
                )
                .cornerRadius(
                    12
                )
            }
        }
        .navigationTitle(
            "Cadastro"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .tint(
            .pink
        )
    }

    private func criarConta() {

        erroApelido = ""

        let apelidoLimpo = apelido
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if apelidoLimpo.count < 2 {

            erroApelido =
                "Escolha um apelido com pelo menos 2 caracteres."

            return
        }

        if apelidoLimpo.count > 25 {

            erroApelido =
                "O apelido pode ter no máximo 25 caracteres."

            return
        }

        let emailLimpo = email
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        let sucesso = auth.cadastrar(
            email: emailLimpo,
            senha: senha,
            confirmarSenha:
                confirmarSenha
        )

        if sucesso {

            perfilStore
                .atualizarApelido(
                    email:
                        emailLimpo,
                    apelido:
                        apelidoLimpo
                )
        }
    }
}


// MARK: - BOAS-VINDAS

struct BoasVindasView: View {

    @ObservedObject
    var auth:
        LocalAuthStore

    var body: some View {

        ZStack {

            Color.pink
                .opacity(0.06)
                .ignoresSafeArea()

            ScrollView {

                VStack(
                    spacing: 24
                ) {

                    ZStack {

                        Circle()
                            .fill(
                                Color.pink
                                    .opacity(0.12)
                            )
                            .frame(
                                width: 110,
                                height: 110
                            )

                        Image(
                            systemName:
                                "mappin.and.ellipse"
                        )
                        .font(
                            .system(
                                size: 50
                            )
                        )
                        .foregroundColor(
                            .pink
                        )
                    }
                    .padding(
                        .top,
                        25
                    )

                    Text(
                        "Bem-vindo(a) ao JobRate!"
                    )
                    .font(
                        .largeTitle
                    )
                    .bold()
                    .multilineTextAlignment(
                        .center
                    )

                    Text(
                        "Encontre empresas no mapa e compartilhe experiências profissionais."
                    )
                    .foregroundColor(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .center
                    )

                    InfoCard(
                        icone:
                            "location.fill",
                        titulo:
                            "Veja sua localização",
                        texto:
                            "Use o mapa para encontrar empresas e locais próximos."
                    )

                    InfoCard(
                        icone:
                            "magnifyingglass",
                        titulo:
                            "Pesquise empresas",
                        texto:
                            "Encontre no Apple Maps onde você trabalhou."
                    )

                    InfoCard(
                        icone:
                            "star.fill",
                        titulo:
                            "Avalie",
                        texto:
                            "Dê de 1 a 5 estrelas e conte como foi sua experiência."
                    )

                    InfoCard(
                        icone:
                            "person.2.fill",
                        titulo:
                            "Questões de gênero",
                        texto:
                            "Compartilhe experiências sobre assédio, discriminação, desigualdade salarial, respeito e oportunidades."
                    )

                    Button {

                        auth
                            .continuarParaApp()

                    } label: {

                        Text(
                            "Abrir mapa"
                        )
                        .bold()
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .frame(
                            height: 55
                        )
                    }
                    .foregroundColor(
                        .white
                    )
                    .background(
                        Color.pink
                    )
                    .cornerRadius(
                        15
                    )
                    .padding(
                        .bottom,
                        30
                    )
                }
                .padding(
                    22
                )
            }
        }
        .toolbar(
            .hidden,
            for:
                .navigationBar
        )
    }
}


// MARK: - INFO CARD

struct InfoCard: View {

    var icone: String
    var titulo: String
    var texto: String

    var body: some View {

        HStack(
            alignment: .top,
            spacing: 15
        ) {

            ZStack {

                RoundedRectangle(
                    cornerRadius: 14
                )
                .fill(
                    Color.pink
                        .opacity(0.12)
                )
                .frame(
                    width: 52,
                    height: 52
                )

                Image(
                    systemName: icone
                )
                .foregroundColor(
                    .pink
                )
                .font(
                    .title3
                )
            }

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(
                    titulo
                )
                .font(
                    .headline
                )

                Text(
                    texto
                )
                .font(
                    .subheadline
                )
                .foregroundColor(
                    .secondary
                )
            }

            Spacer()
        }
        .padding()
        .background(
            Color.white
        )
        .cornerRadius(
            17
        )
    }
}


// MARK: - HOME

struct HomeView: View {

    @ObservedObject
    var auth:
        LocalAuthStore

    @ObservedObject
    var avaliacoesStore:
        AvaliacoesStore

    @ObservedObject
    var perfilStore:
        PerfilStore

    @StateObject
    private var pesquisa =
        PesquisaLocaisModel()

    @StateObject
    private var localizacao =
        LocalizacaoManager()

    @State
    private var localSelecionado:
        LocalEncontrado?

    @State
    private var abrirDetalhe =
        false

    @State
    private var centralizarToken =
        0

    private var email: String {

        auth
            .usuarioAtual?
            .email
        ?? ""
    }

    private var perfil:
        PerfilUsuario {

        perfilStore
            .perfil(
                email: email
            )
    }

    var body: some View {

        ZStack {

            MapaPrincipalView(
                localizacaoUsuario:
                    localizacao
                        .localizacaoAtual,
                localSelecionado:
                    localSelecionado,
                centralizarToken:
                    centralizarToken
            )
            .ignoresSafeArea()

            VStack(
                spacing: 0
            ) {

                HStack {

                    Text(
                        "JobRate"
                    )
                    .font(
                        .title2
                    )
                    .bold()

                    Spacer()

                    NavigationLink {

                        PerfilView(
                            email: email,
                            perfilStore:
                                perfilStore,
                            avaliacoesStore:
                                avaliacoesStore,
                            auth: auth
                        )

                    } label: {

                        AvatarPerfilView(
                            perfil: perfil,
                            tamanho: 42
                        )
                    }
                }
                .padding()
                .background(
                    .ultraThinMaterial
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )
                .padding(
                    .horizontal,
                    16
                )
                .padding(
                    .top,
                    8
                )

                Spacer()

                HStack {

                    Spacer()

                    Button {

                        centralizarToken += 1

                        localizacao
                            .atualizarLocalizacao()

                    } label: {

                        Image(
                            systemName:
                                "location.fill"
                        )
                        .foregroundColor(
                            .pink
                        )
                        .frame(
                            width: 50,
                            height: 50
                        )
                        .background(
                            Color.white
                        )
                        .clipShape(
                            Circle()
                        )
                        .shadow(
                            radius: 6
                        )
                    }
                }
                .padding(
                    .horizontal,
                    20
                )
                .padding(
                    .bottom,
                    10
                )

                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {

                    Text(
                        "Onde você trabalhou?"
                    )
                    .font(
                        .system(
                            size: 25,
                            weight: .bold
                        )
                    )

                    Text(
                        "Pesquise uma empresa ou estabelecimento"
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundColor(
                        .secondary
                    )

                    HStack {

                        Image(
                            systemName:
                                "magnifyingglass"
                        )
                        .foregroundColor(
                            .gray
                        )

                        TextField(
                            "Buscar local",
                            text:
                                $pesquisa.texto
                        )
                        .submitLabel(
                            .search
                        )
                        .onSubmit {

                            pesquisa
                                .pesquisarTextoDigitado {
                                    local in

                                    selecionarLocal(
                                        local
                                    )
                                }
                        }

                        if !pesquisa
                            .texto
                            .isEmpty {

                            Button {

                                pesquisa
                                    .limpar()

                            } label: {

                                Image(
                                    systemName:
                                        "xmark.circle.fill"
                                )
                                .foregroundColor(
                                    .gray
                                )
                            }
                        }
                    }
                    .padding()
                    .background(
                        Color.gray
                            .opacity(0.10)
                    )
                    .cornerRadius(
                        14
                    )

                    if pesquisa.carregando {

                        ProgressView(
                            "Localizando..."
                        )
                    }

                    if !pesquisa
                        .mensagemErro
                        .isEmpty {

                        Text(
                            pesquisa
                                .mensagemErro
                        )
                        .font(
                            .caption
                        )
                        .foregroundColor(
                            .red
                        )
                    }

                    if !pesquisa
                        .sugestoes
                        .isEmpty {

                        ScrollView {

                            VStack(
                                spacing: 0
                            ) {

                                ForEach(
                                    Array(
                                        pesquisa
                                            .sugestoes
                                            .enumerated()
                                    ),
                                    id: \.offset
                                ) {
                                    indice,
                                    sugestao in

                                    Button {

                                        pesquisa
                                            .resolver(
                                                sugestao
                                            ) {
                                                local in

                                                selecionarLocal(
                                                    local
                                                )
                                            }

                                    } label: {

                                        HStack {

                                            Image(
                                                systemName:
                                                    "mappin.circle.fill"
                                            )
                                            .foregroundColor(
                                                .pink
                                            )

                                            VStack(
                                                alignment:
                                                    .leading
                                            ) {

                                                Text(
                                                    sugestao.title
                                                )
                                                .bold()
                                                .foregroundColor(
                                                    .primary
                                                )

                                                if !sugestao
                                                    .subtitle
                                                    .isEmpty {

                                                    Text(
                                                        sugestao.subtitle
                                                    )
                                                    .font(
                                                        .caption
                                                    )
                                                    .foregroundColor(
                                                        .secondary
                                                    )
                                                }
                                            }

                                            Spacer()
                                        }
                                        .padding(
                                            .vertical,
                                            10
                                        )
                                    }

                                    if indice <
                                        pesquisa
                                            .sugestoes
                                            .count - 1 {

                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(
                            maxHeight: 250
                        )
                    }
                }
                .padding(
                    22
                )
                .background(
                    Color.white
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 28
                    )
                )
                .shadow(
                    color:
                        Color.black
                        .opacity(0.12),
                    radius: 15,
                    y: -3
                )
                .padding(
                    .horizontal,
                    10
                )
                .padding(
                    .bottom,
                    8
                )
            }
        }
        .toolbar(
            .hidden,
            for:
                .navigationBar
        )
        .onAppear {

            localizacao
                .solicitarPermissao()
        }
        .onReceive(
            localizacao
                .$localizacaoAtual
        ) {
            novaLocalizacao in

            if let coordenada =
                novaLocalizacao?
                    .coordinate {

                pesquisa
                    .atualizarRegiao(
                        com: coordenada
                    )
            }
        }
        .navigationDestination(
            isPresented:
                $abrirDetalhe
        ) {

            if let local =
                localSelecionado {

                DetalheLocalView(
                    local: local,
                    emailUsuario:
                        email,
                    avaliacoesStore:
                        avaliacoesStore,
                    perfilStore:
                        perfilStore
                )
            }
        }
    }

    private func selecionarLocal(
        _ local:
            LocalEncontrado?
    ) {

        guard let local else {
            return
        }

        localSelecionado = local

        abrirDetalhe = true
    }
}


// MARK: - PERFIL

struct PerfilView: View {

    let email: String

    @ObservedObject
    var perfilStore:
        PerfilStore

    @ObservedObject
    var avaliacoesStore:
        AvaliacoesStore

    @ObservedObject
    var auth:
        LocalAuthStore

    @State
    private var fotoSelecionada:
        PhotosPickerItem?

    @State
    private var apelidoEdicao = ""

    @State
    private var mensagemApelido = ""

    private var perfil:
        PerfilUsuario {

        perfilStore
            .perfil(
                email: email
            )
    }

    private var minhasAvaliacoes:
        [AvaliacaoLocal] {

        avaliacoesStore
            .avaliacoes(
                doUsuario: email
            )
    }

    var body: some View {

        ScrollView {

            VStack(
                spacing: 24
            ) {

                // FOTO + APELIDO

                VStack(
                    spacing: 14
                ) {

                    PhotosPicker(
                        selection:
                            $fotoSelecionada,
                        matching:
                            .images
                    ) {

                        ZStack(
                            alignment:
                                .bottomTrailing
                        ) {

                            AvatarPerfilView(
                                perfil: perfil,
                                tamanho: 110
                            )

                            Image(
                                systemName:
                                    "camera.fill"
                            )
                            .font(
                                .caption
                            )
                            .foregroundColor(
                                .white
                            )
                            .frame(
                                width: 34,
                                height: 34
                            )
                            .background(
                                perfil
                                    .corPerfil
                                    .cor
                            )
                            .clipShape(
                                Circle()
                            )
                        }
                    }

                    Text(
                        perfil.nomeExibicao
                    )
                    .font(
                        .title2
                    )
                    .bold()

                    Text(
                        email
                    )
                    .font(
                        .caption
                    )
                    .foregroundColor(
                        .secondary
                    )

                    if perfil.fotoData != nil {

                        Button(
                            "Remover foto"
                        ) {

                            perfilStore
                                .removerFoto(
                                    email: email
                                )
                        }
                        .font(
                            .caption
                        )
                        .foregroundColor(
                            .red
                        )
                    }
                }
                .frame(
                    maxWidth:
                        .infinity
                )
                .padding(
                    .top,
                    10
                )

                // EDITAR APELIDO

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    Text(
                        "Apelido"
                    )
                    .font(
                        .headline
                    )

                    TextField(
                        "Seu apelido",
                        text:
                            $apelidoEdicao
                    )
                    .textInputAutocapitalization(
                        .words
                    )
                    .autocorrectionDisabled()
                    .padding()
                    .background(
                        Color.gray
                            .opacity(0.08)
                    )
                    .cornerRadius(
                        12
                    )

                    if !mensagemApelido.isEmpty {

                        Text(
                            mensagemApelido
                        )
                        .font(
                            .caption
                        )
                        .foregroundColor(
                            mensagemApelido ==
                            "Apelido salvo!"
                            ? .green
                            : .red
                        )
                    }

                    Button {

                        salvarApelido()

                    } label: {

                        Text(
                            "Salvar apelido"
                        )
                        .bold()
                        .frame(
                            maxWidth:
                                .infinity
                        )
                        .frame(
                            height: 46
                        )
                    }
                    .foregroundColor(
                        .white
                    )
                    .background(
                        perfil
                            .corPerfil
                            .cor
                    )
                    .cornerRadius(
                        12
                    )
                }
                .padding(
                    18
                )
                .background(
                    Color.white
                )
                .cornerRadius(
                    18
                )

                // COR DO PERFIL

                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {

                    Text(
                        "Cor do perfil"
                    )
                    .font(
                        .headline
                    )

                    HStack(
                        spacing: 18
                    ) {

                        ForEach(
                            CorPerfil
                                .allCases
                        ) {
                            cor in

                            Button {

                                perfilStore
                                    .atualizarCor(
                                        email: email,
                                        cor: cor
                                    )

                            } label: {

                                ZStack {

                                    Circle()
                                        .fill(
                                            cor.cor
                                        )
                                        .frame(
                                            width: 42,
                                            height: 42
                                        )

                                    if perfil
                                        .corPerfil ==
                                        cor {

                                        Image(
                                            systemName:
                                                "checkmark"
                                        )
                                        .bold()
                                        .foregroundColor(
                                            .white
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(
                    18
                )
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        .leading
                )
                .background(
                    Color.white
                )
                .cornerRadius(
                    18
                )

                // NÚMEROS

                HStack(
                    spacing: 14
                ) {

                    PerfilNumeroCard(
                        numero:
                            minhasAvaliacoes.count,
                        titulo:
                            "Avaliações",
                        icone:
                            "star.fill",
                        cor:
                            perfil
                                .corPerfil
                                .cor
                    )

                    PerfilNumeroCard(
                        numero:
                            perfil
                                .locaisTrabalhados
                                .count,
                        titulo:
                            "Locais",
                        icone:
                            "building.2.fill",
                        cor:
                            perfil
                                .corPerfil
                                .cor
                    )
                }

                // ONDE TRABALHEI

                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {

                    Text(
                        "Onde trabalhei"
                    )
                    .font(
                        .title2
                    )
                    .bold()

                    if perfil
                        .locaisTrabalhados
                        .isEmpty {

                        Text(
                            "Você ainda não adicionou nenhum local."
                        )
                        .font(
                            .subheadline
                        )
                        .foregroundColor(
                            .secondary
                        )
                        .padding(
                            .vertical,
                            12
                        )

                    } else {

                        ForEach(
                            perfil
                                .locaisTrabalhados
                        ) {
                            local in

                            HStack(
                                spacing: 14
                            ) {

                                Image(
                                    systemName:
                                        "building.2.fill"
                                )
                                .foregroundColor(
                                    perfil
                                        .corPerfil
                                        .cor
                                )
                                .frame(
                                    width: 42,
                                    height: 42
                                )
                                .background(
                                    perfil
                                        .corPerfil
                                        .cor
                                        .opacity(0.12)
                                )
                                .clipShape(
                                    Circle()
                                )

                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {

                                    Text(
                                        local.nome
                                    )
                                    .bold()

                                    Text(
                                        local.endereco
                                    )
                                    .font(
                                        .caption
                                    )
                                    .foregroundColor(
                                        .secondary
                                    )
                                    .lineLimit(
                                        2
                                    )
                                }

                                Spacer()
                            }
                            .padding(
                                14
                            )
                            .background(
                                Color.white
                            )
                            .cornerRadius(
                                14
                            )
                        }
                    }
                }
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        .leading
                )

                // MINHAS AVALIAÇÕES

                VStack(
                    alignment: .leading,
                    spacing: 14
                ) {

                    Text(
                        "Minhas avaliações"
                    )
                    .font(
                        .title2
                    )
                    .bold()

                    if minhasAvaliacoes
                        .isEmpty {

                        Text(
                            "Você ainda não publicou avaliações."
                        )
                        .foregroundColor(
                            .secondary
                        )
                        .padding(
                            .vertical,
                            12
                        )

                    } else {

                        ForEach(
                            minhasAvaliacoes
                        ) {
                            avaliacao in

                            MinhaAvaliacaoCard(
                                avaliacao:
                                    avaliacao,
                                cor:
                                    perfil
                                        .corPerfil
                                        .cor
                            )
                        }
                    }
                }
                .frame(
                    maxWidth:
                        .infinity,
                    alignment:
                        .leading
                )

                Button(
                    role: .destructive
                ) {

                    auth.sair()

                } label: {

                    Label(
                        "Sair da conta",
                        systemImage:
                            "rectangle.portrait.and.arrow.right"
                    )
                    .bold()
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        height: 52
                    )
                }
                .background(
                    Color.red
                        .opacity(0.08)
                )
                .cornerRadius(
                    14
                )
                .padding(
                    .bottom,
                    20
                )
            }
            .padding(
                20
            )
        }
        .background(
            perfil
                .corPerfil
                .cor
                .opacity(0.05)
        )
        .navigationTitle(
            "Perfil"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .tint(
            perfil
                .corPerfil
                .cor
        )
        .onAppear {

            apelidoEdicao =
                perfil.apelido ?? ""
        }
        .onChange(
            of: fotoSelecionada
        ) {
            _,
            novoItem in

            guard let novoItem else {
                return
            }

            Task {

                if let dados = try? await novoItem
                    .loadTransferable(
                        type: Data.self
                    ) {

                    await MainActor.run {

                        perfilStore
                            .atualizarFoto(
                                email: email,
                                dados: dados
                            )
                    }
                }
            }
        }
    }

    private func salvarApelido() {

        mensagemApelido = ""

        let apelidoLimpo = apelidoEdicao
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if apelidoLimpo.count < 2 {

            mensagemApelido =
                "Use pelo menos 2 caracteres."

            return
        }

        if apelidoLimpo.count > 25 {

            mensagemApelido =
                "Use no máximo 25 caracteres."

            return
        }

        perfilStore
            .atualizarApelido(
                email: email,
                apelido:
                    apelidoLimpo
            )

        apelidoEdicao =
            apelidoLimpo

        mensagemApelido =
            "Apelido salvo!"
    }
}


// MARK: - CARD DE NÚMEROS

struct PerfilNumeroCard: View {

    let numero: Int
    let titulo: String
    let icone: String
    let cor: Color

    var body: some View {

        VStack(
            spacing: 8
        ) {

            Image(
                systemName: icone
            )
            .foregroundColor(
                cor
            )

            Text(
                "\(numero)"
            )
            .font(
                .title2
            )
            .bold()

            Text(
                titulo
            )
            .font(
                .caption
            )
            .foregroundColor(
                .secondary
            )
        }
        .frame(
            maxWidth:
                .infinity
        )
        .padding(
            .vertical,
            18
        )
        .background(
            Color.white
        )
        .cornerRadius(
            16
        )
    }
}


// MARK: - MINHA AVALIAÇÃO

struct MinhaAvaliacaoCard: View {

    let avaliacao:
        AvaliacaoLocal

    let cor:
        Color

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            HStack {

                Image(
                    systemName:
                        "building.2.fill"
                )
                .foregroundColor(
                    cor
                )

                Text(
                    avaliacao
                        .localNome
                )
                .bold()

                Spacer()
            }

            HStack(
                spacing: 3
            ) {

                ForEach(
                    1...5,
                    id: \.self
                ) {
                    estrela in

                    Image(
                        systemName:
                            estrela <=
                            avaliacao
                                .estrelas

                            ? "star.fill"

                            : "star"
                    )
                    .foregroundColor(
                        .yellow
                    )
                }
            }

            Text(
                avaliacao
                    .comentario
            )

            Text(
                avaliacao
                    .data
                    .formatted(
                        date:
                            .abbreviated,
                        time:
                            .omitted
                    )
            )
            .font(
                .caption
            )
            .foregroundColor(
                .secondary
            )
        }
        .padding(
            16
        )
        .background(
            Color.white
        )
        .cornerRadius(
            16
        )
    }
}


// MARK: - DETALHE DO LOCAL

struct DetalheLocalView: View {

    let local:
        LocalEncontrado

    let emailUsuario:
        String

    @ObservedObject
    var avaliacoesStore:
        AvaliacoesStore

    @ObservedObject
    var perfilStore:
        PerfilStore

    @State
    private var filtroSelecionado:
        FiltroAvaliacao =
        .todas

    private var avaliacoesDoLocal:
        [AvaliacaoLocal] {

        avaliacoesStore
            .avaliacoes(
                do: local.id
            )
    }

    private var avaliacoesBoas:
        [AvaliacaoLocal] {

        avaliacoesDoLocal
            .filter {
                $0.estrelas >= 4
            }
    }

    private var avaliacoesRuins:
        [AvaliacaoLocal] {

        avaliacoesDoLocal
            .filter {
                $0.estrelas <= 2
            }
    }

    private var avaliacoesFiltradas:
        [AvaliacaoLocal] {

        switch filtroSelecionado {

        case .todas:
            return avaliacoesDoLocal

        case .boas:
            return avaliacoesBoas

        case .ruins:
            return avaliacoesRuins
        }
    }

    private var media:
        Double {

        guard !avaliacoesDoLocal
            .isEmpty
        else {
            return 0
        }

        let total =
            avaliacoesDoLocal
                .reduce(0) {
                    $0 + $1.estrelas
                }

        return
            Double(total)
            /
            Double(
                avaliacoesDoLocal.count
            )
    }

    private var porcentagemReputacao:
        Double {

        guard !avaliacoesDoLocal
            .isEmpty
        else {
            return 0
        }

        return
            (media / 5)
            * 100
    }

    private var textoReputacao:
        String {

        if avaliacoesDoLocal.isEmpty {
            return "Sem avaliações"
        }

        if media >= 4.5 {
            return "Excelente"
        }

        if media >= 4 {
            return "Muito boa"
        }

        if media >= 3 {
            return "Regular"
        }

        if media >= 2 {
            return "Ruim"
        }

        return "Muito ruim"
    }

    private var corReputacao:
        Color {

        if avaliacoesDoLocal
            .isEmpty {
            return .gray
        }

        if media >= 4 {
            return .green
        }

        if media >= 3 {
            return .orange
        }

        return .red
    }

    private var localAdicionado:
        Bool {

        perfilStore
            .temLocal(
                email:
                    emailUsuario,
                localID:
                    local.id
            )
    }

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 22
            ) {

                AppleMapLocalView(
                    local: local
                )
                .frame(
                    height: 235
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 20
                    )
                )

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text(
                        local.nome
                    )
                    .font(
                        .title
                    )
                    .bold()

                    Label(
                        local.endereco,
                        systemImage:
                            "mappin.and.ellipse"
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundColor(
                        .secondary
                    )
                }

                Button {

                    perfilStore
                        .alternarLocal(
                            email:
                                emailUsuario,
                            local:
                                local
                        )

                } label: {

                    Label(

                        localAdicionado
                        ? "Local Adicionado ao Perfil"
                        : "Já Trabalhei Aqui",

                        systemImage:

                            localAdicionado
                            ? "checkmark.circle.fill"
                            : "briefcase.fill"
                    )
                    .bold()
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        height: 50
                    )
                }
                .foregroundColor(
                    localAdicionado
                    ? .green
                    : .pink
                )
                .background(
                    (
                        localAdicionado
                        ? Color.green
                        : Color.pink
                    )
                    .opacity(0.10)
                )
                .cornerRadius(
                    14
                )

                // REPUTAÇÃO

                VStack(
                    alignment: .leading,
                    spacing: 15
                ) {

                    HStack {

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {

                            Text(
                                "Reputação"
                            )
                            .font(
                                .headline
                            )

                            Text(
                                textoReputacao
                            )
                            .font(
                                .title2
                            )
                            .bold()
                            .foregroundColor(
                                corReputacao
                            )
                        }

                        Spacer()

                        if !avaliacoesDoLocal
                            .isEmpty {

                            Text(
                                "\(Int(porcentagemReputacao.rounded()))%"
                            )
                            .font(
                                .system(
                                    size: 28,
                                    weight: .bold
                                )
                            )
                        }
                    }

                    ProgressView(
                        value:
                            porcentagemReputacao,
                        total:
                            100
                    )
                    .tint(
                        corReputacao
                    )
                    .scaleEffect(
                        x: 1,
                        y: 2.2,
                        anchor: .center
                    )

                    HStack {

                        Label(
                            "\(avaliacoesBoas.count) boas",
                            systemImage:
                                "hand.thumbsup.fill"
                        )
                        .font(
                            .caption
                        )
                        .foregroundColor(
                            .green
                        )

                        Spacer()

                        Label(
                            "\(avaliacoesRuins.count) ruins",
                            systemImage:
                                "hand.thumbsdown.fill"
                        )
                        .font(
                            .caption
                        )
                        .foregroundColor(
                            .red
                        )
                    }
                }
                .padding(
                    18
                )
                .background(
                    Color.white
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )
                .shadow(
                    color:
                        Color.black
                        .opacity(0.05),
                    radius: 8,
                    y: 3
                )

                // NOTA

                HStack {

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        Text(
                            "Nota geral"
                        )
                        .font(
                            .headline
                        )

                        HStack(
                            spacing: 4
                        ) {

                            ForEach(
                                1...5,
                                id: \.self
                            ) {
                                estrela in

                                Image(
                                    systemName:
                                        Double(estrela)
                                        <= media

                                        ? "star.fill"

                                        : "star"
                                )
                                .foregroundColor(
                                    .yellow
                                )
                            }
                        }
                    }

                    Spacer()

                    VStack(
                        alignment: .trailing,
                        spacing: 3
                    ) {

                        Text(
                            avaliacoesDoLocal
                                .isEmpty

                            ? "--"

                            : String(
                                format: "%.1f",
                                media
                            )
                        )
                        .font(
                            .title
                        )
                        .bold()

                        Text(
                            "\(avaliacoesDoLocal.count) avaliações"
                        )
                        .font(
                            .caption
                        )
                        .foregroundColor(
                            .secondary
                        )
                    }
                }

                NavigationLink {

                    AvaliarLocalView(
                        local: local,
                        emailUsuario:
                            emailUsuario,
                        avaliacoesStore:
                            avaliacoesStore
                    )

                } label: {

                    Label(
                        "Avaliar este local",
                        systemImage:
                            "star.bubble.fill"
                    )
                    .bold()
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        height: 55
                    )
                }
                .foregroundColor(
                    .white
                )
                .background(
                    Color.pink
                )
                .cornerRadius(
                    15
                )

                Divider()

                Text(
                    "Experiências"
                )
                .font(
                    .title2
                )
                .bold()

                Picker(
                    "Filtrar avaliações",
                    selection:
                        $filtroSelecionado
                ) {

                    ForEach(
                        FiltroAvaliacao
                            .allCases
                    ) {
                        filtro in

                        Text(
                            filtro.rawValue
                        )
                        .tag(
                            filtro
                        )
                    }
                }
                .pickerStyle(
                    .segmented
                )

                if avaliacoesFiltradas
                    .isEmpty {

                    VStack(
                        spacing: 12
                    ) {

                        Image(
                            systemName:
                                "bubble.left"
                        )
                        .font(
                            .system(
                                size: 38
                            )
                        )
                        .foregroundColor(
                            .secondary
                        )

                        Text(
                            "Nenhuma avaliação encontrada."
                        )
                        .foregroundColor(
                            .secondary
                        )
                    }
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .padding(
                        .vertical,
                        30
                    )

                } else {

                    ForEach(
                        avaliacoesFiltradas
                    ) {
                        avaliacao in

                        AvaliacaoCard(
                            avaliacao:
                                avaliacao,
                            perfilStore:
                                perfilStore
                        )
                    }
                }
            }
            .padding(
                20
            )
        }
        .background(
            Color.pink
                .opacity(0.04)
        )
        .navigationTitle(
            "Local"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }
}


// MARK: - NOVA AVALIAÇÃO

struct AvaliarLocalView: View {

    let local:
        LocalEncontrado

    let emailUsuario:
        String

    @ObservedObject
    var avaliacoesStore:
        AvaliacoesStore

    @Environment(
        \.dismiss
    )
    private var dismiss

    @State
    private var estrelas = 0

    @State
    private var comentario = ""

    @State
    private var categoriasSelecionadas:
        Set<String> = []

    @State
    private var mensagemErro = ""

    private let categorias = [

        "Assédio ou comportamento inadequado",

        "Desigualdade salarial",

        "Discriminação de gênero",

        "Desrespeito à identidade de gênero",

        "Falta de oportunidades",

        "Ambiente acolhedor",

        "Igualdade de oportunidades"
    ]

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 22
            ) {

                Text(
                    local.nome
                )
                .font(
                    .title2
                )
                .bold()

                Text(
                    "Como foi sua experiência?"
                )
                .font(
                    .headline
                )

                HStack(
                    spacing: 12
                ) {

                    ForEach(
                        1...5,
                        id: \.self
                    ) {
                        estrela in

                        Button {

                            estrelas =
                                estrela

                        } label: {

                            Image(
                                systemName:
                                    estrela <= estrelas

                                    ? "star.fill"

                                    : "star"
                            )
                            .font(
                                .system(
                                    size: 34
                                )
                            )
                            .foregroundColor(
                                .yellow
                            )
                        }
                    }
                }

                Divider()

                Text(
                    "O que se relaciona à sua experiência?"
                )
                .font(
                    .headline
                )

                Text(
                    "Você pode marcar mais de uma opção."
                )
                .font(
                    .caption
                )
                .foregroundColor(
                    .secondary
                )

                ForEach(
                    categorias,
                    id: \.self
                ) {
                    categoria in

                    Button {

                        if categoriasSelecionadas
                            .contains(
                                categoria
                            ) {

                            categoriasSelecionadas
                                .remove(
                                    categoria
                                )

                        } else {

                            categoriasSelecionadas
                                .insert(
                                    categoria
                                )
                        }

                    } label: {

                        HStack {

                            Image(
                                systemName:
                                    categoriasSelecionadas
                                    .contains(
                                        categoria
                                    )

                                    ? "checkmark.circle.fill"

                                    : "circle"
                            )
                            .foregroundColor(
                                .pink
                            )

                            Text(
                                categoria
                            )
                            .foregroundColor(
                                .primary
                            )

                            Spacer()
                        }
                        .padding()
                        .background(
                            Color.white
                        )
                        .cornerRadius(
                            12
                        )
                    }
                    .buttonStyle(
                        .plain
                    )
                }

                Divider()

                Text(
                    "Conte sua experiência"
                )
                .font(
                    .headline
                )

                Text(
                    "Evite publicar nomes, telefones ou dados pessoais de outras pessoas."
                )
                .font(
                    .caption
                )
                .foregroundColor(
                    .secondary
                )

                TextEditor(
                    text:
                        $comentario
                )
                .frame(
                    minHeight: 150
                )
                .padding(
                    8
                )
                .background(
                    Color.white
                )
                .cornerRadius(
                    12
                )

                if !mensagemErro
                    .isEmpty {

                    Text(
                        mensagemErro
                    )
                    .foregroundColor(
                        .red
                    )
                    .font(
                        .caption
                    )
                }

                Button {

                    publicar()

                } label: {

                    Label(
                        "Publicar avaliação",
                        systemImage:
                            "paperplane.fill"
                    )
                    .bold()
                    .frame(
                        maxWidth:
                            .infinity
                    )
                    .frame(
                        height: 55
                    )
                }
                .foregroundColor(
                    .white
                )
                .background(
                    Color.pink
                )
                .cornerRadius(
                    15
                )
            }
            .padding(
                20
            )
        }
        .background(
            Color.pink
                .opacity(0.04)
        )
        .navigationTitle(
            "Nova avaliação"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }

    private func publicar() {

        mensagemErro = ""

        let texto = comentario
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard estrelas > 0 else {

            mensagemErro =
                "Escolha de 1 a 5 estrelas."

            return
        }

        guard !texto.isEmpty else {

            mensagemErro =
                "Escreva um comentário."

            return
        }

        avaliacoesStore
            .adicionar(

                local: local,

                email:
                    emailUsuario,

                estrelas:
                    estrelas,

                comentario:
                    texto,

                categorias:
                    Array(
                        categoriasSelecionadas
                    )
                    .sorted()
            )

        dismiss()
    }
}


// MARK: - CARD DA AVALIAÇÃO NA EMPRESA

struct AvaliacaoCard: View {

    let avaliacao:
        AvaliacaoLocal

    @ObservedObject
    var perfilStore:
        PerfilStore

    private var positiva:
        Bool {

        avaliacao.estrelas >= 4
    }

    private var negativa:
        Bool {

        avaliacao.estrelas <= 2
    }

    private var perfilAutor:
        PerfilUsuario {

        perfilStore
            .perfil(
                email:
                    avaliacao
                        .emailAutor
            )
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack {

                // 4 OU 5 ESTRELAS:
                // mostra foto e apelido

                if positiva {

                    AvatarPerfilView(
                        perfil:
                            perfilAutor,
                        tamanho: 38
                    )

                    Text(
                        perfilAutor
                            .nomeExibicao
                    )
                    .font(
                        .headline
                    )

                } else {

                    // 1, 2 ou 3 estrelas:
                    // mantém anônimo

                    Image(
                        systemName:
                            "person.crop.circle.fill"
                    )
                    .font(
                        .system(
                            size: 38
                        )
                    )
                    .foregroundColor(
                        .gray
                    )

                    Text(
                        "Anônimo"
                    )
                    .font(
                        .headline
                    )
                }

                Spacer()

                if positiva {

                    Label(
                        "Positiva",
                        systemImage:
                            "hand.thumbsup.fill"
                    )
                    .font(
                        .caption
                    )
                    .foregroundColor(
                        .green
                    )

                } else if negativa {

                    Label(
                        "Negativa",
                        systemImage:
                            "hand.thumbsdown.fill"
                    )
                    .font(
                        .caption
                    )
                    .foregroundColor(
                        .red
                    )

                } else {

                    Text(
                        "Neutra"
                    )
                    .font(
                        .caption
                    )
                    .foregroundColor(
                        .orange
                    )
                }
            }

            HStack(
                spacing: 3
            ) {

                ForEach(
                    1...5,
                    id: \.self
                ) {
                    estrela in

                    Image(
                        systemName:
                            estrela <=
                            avaliacao
                                .estrelas

                            ? "star.fill"

                            : "star"
                    )
                    .foregroundColor(
                        .yellow
                    )
                }
            }

            if !avaliacao
                .categorias
                .isEmpty {

                ForEach(
                    avaliacao
                        .categorias,
                    id: \.self
                ) {
                    categoria in

                    Label(
                        categoria,
                        systemImage:
                            "tag.fill"
                    )
                    .font(
                        .caption
                    )
                    .foregroundColor(
                        .pink
                    )
                }
            }

            Text(
                avaliacao
                    .comentario
            )

            Text(
                avaliacao
                    .data
                    .formatted(
                        date:
                            .abbreviated,
                        time:
                            .omitted
                    )
            )
            .font(
                .caption2
            )
            .foregroundColor(
                .secondary
            )
        }
        .padding(
            16
        )
        .background(
            Color.white
        )
        .cornerRadius(
            16
        )
        .shadow(
            color:
                Color.black
                .opacity(0.05),
            radius: 7,
            y: 3
        )
    }
}


// MARK: - PREVIEW

#Preview {
    ContentView()
}
