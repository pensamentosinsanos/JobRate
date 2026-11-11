import SwiftUI
import Combine
import MapKit
import CoreLocation
import PhotosUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - AVATARES DO JOBRATE

struct AvatarPadrao: Identifiable, Hashable {
    let id: String

    var nomeAsset: String { id }

    static let todos: [AvatarPadrao] = [
        AvatarPadrao(id: "anon1"),
        AvatarPadrao(id: "anon2"),
        AvatarPadrao(id: "anon3"),
        AvatarPadrao(id: "anon4"),
        AvatarPadrao(id: "anon5")
    ]

    static func aleatorio() -> String {
        todos.randomElement()?.nomeAsset ?? "anon1"
    }

    static func baseadoNoID(_ id: String) -> String {
        let soma = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return todos[soma % todos.count].nomeAsset
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
        endereco = Self.montarEndereco(placemark: mapItem.placemark)
        id = "\(nome.lowercased())-\(latitude)-\(longitude)"
    }

    private static func montarEndereco(placemark: MKPlacemark) -> String {
        var partes: [String] = []

        if let rua = placemark.thoroughfare {
            if let numero = placemark.subThoroughfare {
                partes.append("\(rua), \(numero)")
            } else {
                partes.append(rua)
            }
        }

        if let bairro = placemark.subLocality { partes.append(bairro) }
        if let cidade = placemark.locality { partes.append(cidade) }
        if let estado = placemark.administrativeArea { partes.append(estado) }

        return partes.isEmpty
            ? (placemark.title ?? "Endereço não disponível")
            : partes.joined(separator: " • ")
    }
}

// MARK: - LOCAL TRABALHADO

struct LocalTrabalhado: Identifiable, Hashable {
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

    init?(firestore: [String: Any]) {
        guard
            let id = firestore["id"] as? String,
            let nome = firestore["nome"] as? String,
            let endereco = firestore["endereco"] as? String,
            let latitude = firestore["latitude"] as? Double,
            let longitude = firestore["longitude"] as? Double
        else {
            return nil
        }

        self.id = id
        self.nome = nome
        self.endereco = endereco
        self.latitude = latitude
        self.longitude = longitude
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "nome": nome,
            "endereco": endereco,
            "latitude": latitude,
            "longitude": longitude
        ]
    }
}

// MARK: - AVALIAÇÃO

struct AvaliacaoLocal: Identifiable {
    let id: String
    let localID: String
    let localNome: String
    let estrelas: Int
    let comentario: String
    let categorias: [String]
    let avatarAnonimoNome: String?
    let data: Date

    // Só existe nas avaliações de 4 ou 5 estrelas.
    // Avaliações anônimas não armazenam o UID do autor no documento público.
    let publicAuthorUID: String?
}

// MARK: - REAÇÃO

enum TipoReacao: String {
    case concordar
    case discordar
}

struct ReacaoAvaliacao: Identifiable {
    let id: String
    let avaliacaoID: String
    let userUID: String
    let tipo: TipoReacao
}

// MARK: - FILTRO

enum FiltroAvaliacao: String, CaseIterable, Identifiable {
    case todas = "Todas"
    case boas = "Boas"
    case ruins = "Ruins"

    var id: String { rawValue }
}

// MARK: - COR DO PERFIL

enum CorPerfil: String, CaseIterable, Identifiable {
    case rosa
    case roxo
    case azul
    case verde
    case laranja

    var id: String { rawValue }

    var cor: Color {
        switch self {
        case .rosa: return .pink
        case .roxo: return .purple
        case .azul: return .blue
        case .verde: return .green
        case .laranja: return .orange
        }
    }
}

// MARK: - PERFIL

struct PerfilUsuario: Identifiable {
    let id: String
    var apelido: String
    var corPerfil: CorPerfil
    var fotoData: Data?
    var avatarAssetName: String?
    var locaisTrabalhados: [LocalTrabalhado]

    var nomeExibicao: String {
        let nome = apelido.trimmingCharacters(in: .whitespacesAndNewlines)
        return nome.isEmpty ? "Usuário JobRate" : nome
    }
}

// MARK: - AUTENTICAÇÃO FIREBASE

final class FirebaseAuthStore: ObservableObject {
    @Published var usuarioAtual: FirebaseAuth.User?
    @Published var mensagemErro = ""
    @Published var carregando = false
    @Published var mostrarBoasVindas = false

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, usuario in
            DispatchQueue.main.async {
                self?.usuarioAtual = usuario
            }
        }
    }

    deinit {
        if let listener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    func cadastrar(
        apelido: String,
        email: String,
        senha: String,
        confirmarSenha: String
    ) {
        mensagemErro = ""

        let nome = apelido.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailLimpo = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard nome.count >= 2 else {
            mensagemErro = "O apelido precisa ter pelo menos 2 caracteres."
            return
        }

        guard nome.count <= 25 else {
            mensagemErro = "O apelido pode ter no máximo 25 caracteres."
            return
        }

        guard !emailLimpo.isEmpty else {
            mensagemErro = "Digite seu e-mail."
            return
        }

        guard senha.count >= 8 else {
            mensagemErro = "A senha precisa ter pelo menos 8 caracteres."
            return
        }

        guard senha == confirmarSenha else {
            mensagemErro = "As senhas não são iguais."
            return
        }

        carregando = true

        Auth.auth().createUser(withEmail: emailLimpo, password: senha) { [weak self] resultado, erro in
            guard let self else { return }

            if let erro {
                DispatchQueue.main.async {
                    self.carregando = false
                    self.mensagemErro = self.mensagemFirebase(erro)
                }
                return
            }

            guard let uid = resultado?.user.uid else {
                DispatchQueue.main.async {
                    self.carregando = false
                    self.mensagemErro = "Não foi possível criar a conta."
                }
                return
            }

            let perfil: [String: Any] = [
                "apelido": nome,
                "corPerfil": CorPerfil.rosa.rawValue,
                "locaisTrabalhados": [],
                "criadoEm": Timestamp(date: Date())
            ]

            Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData(perfil) { erroPerfil in
                    DispatchQueue.main.async {
                        self.carregando = false

                        if let erroPerfil {
                            self.mensagemErro = "A conta foi criada, mas houve um erro ao criar o perfil: \(erroPerfil.localizedDescription)"
                            return
                        }

                        self.mensagemErro = ""
                        self.mostrarBoasVindas = true
                    }
                }
        }
    }

    func entrar(email: String, senha: String) {
        mensagemErro = ""

        let emailLimpo = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !emailLimpo.isEmpty, !senha.isEmpty else {
            mensagemErro = "Preencha todos os campos."
            return
        }

        carregando = true

        Auth.auth().signIn(withEmail: emailLimpo, password: senha) { [weak self] _, erro in
            guard let self else { return }

            DispatchQueue.main.async {
                self.carregando = false

                if let erro {
                    self.mensagemErro = self.mensagemFirebase(erro)
                } else {
                    self.mensagemErro = ""
                    self.mostrarBoasVindas = false
                }
            }
        }
    }

    func continuarParaApp() {
        mostrarBoasVindas = false
    }

    func sair() {
        do {
            try Auth.auth().signOut()
            usuarioAtual = nil
            mostrarBoasVindas = false
            mensagemErro = ""
        } catch {
            mensagemErro = "Não foi possível sair da conta."
        }
    }

    private func mensagemFirebase(_ erro: Error) -> String {
        let descricao = erro.localizedDescription.lowercased()

        if descricao.contains("email") && descricao.contains("already") {
            return "Este e-mail já está cadastrado."
        }

        if descricao.contains("password") || descricao.contains("credential") {
            return "E-mail ou senha incorretos."
        }

        if descricao.contains("network") {
            return "Confira sua conexão com a internet."
        }

        return erro.localizedDescription
    }
}

// MARK: - PERFIS FIRESTORE

final class PerfilStore: ObservableObject {
    @Published private(set) var perfis: [String: PerfilUsuario] = [:]

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func iniciar() {
        guard listener == nil else { return }

        listener = db.collection("users").addSnapshotListener { [weak self] snapshot, erro in
            guard let self, let documentos = snapshot?.documents, erro == nil else { return }

            var novos: [String: PerfilUsuario] = [:]

            for documento in documentos {
                let dados = documento.data()
                let apelido = dados["apelido"] as? String ?? "Usuário JobRate"
                let corString = dados["corPerfil"] as? String ?? CorPerfil.rosa.rawValue
                let cor = CorPerfil(rawValue: corString) ?? .rosa
                let fotoData = dados["fotoData"] as? Data
                let avatarAssetName = dados["avatarAssetName"] as? String

                let locaisFirestore = dados["locaisTrabalhados"] as? [[String: Any]] ?? []
                let locais = locaisFirestore.compactMap { LocalTrabalhado(firestore: $0) }

                novos[documento.documentID] = PerfilUsuario(
                    id: documento.documentID,
                    apelido: apelido,
                    corPerfil: cor,
                    fotoData: fotoData,
                    avatarAssetName: avatarAssetName,
                    locaisTrabalhados: locais
                )
            }

            DispatchQueue.main.async {
                self.perfis = novos
            }
        }
    }

    func parar() {
        listener?.remove()
        listener = nil
        perfis = [:]
    }

    func perfil(uid: String) -> PerfilUsuario {
        perfis[uid] ?? PerfilUsuario(
            id: uid,
            apelido: "Usuário JobRate",
            corPerfil: .rosa,
            fotoData: nil,
            avatarAssetName: nil,
            locaisTrabalhados: []
        )
    }

    func atualizarApelido(
        uid: String,
        apelido: String,
        conclusao: @escaping (String?) -> Void
    ) {
        let nome = apelido.trimmingCharacters(in: .whitespacesAndNewlines)

        guard nome.count >= 2 else {
            conclusao("Use pelo menos 2 caracteres.")
            return
        }

        guard nome.count <= 25 else {
            conclusao("Use no máximo 25 caracteres.")
            return
        }

        db.collection("users")
            .document(uid)
            .setData(["apelido": nome], merge: true) { erro in
                DispatchQueue.main.async {
                    conclusao(erro == nil ? nil : "Não foi possível salvar o apelido.")
                }
            }
    }

    func atualizarCor(uid: String, cor: CorPerfil) {
        db.collection("users")
            .document(uid)
            .setData(["corPerfil": cor.rawValue], merge: true)
    }

    func atualizarAvatarPadrao(uid: String, nomeAsset: String) {
        db.collection("users")
            .document(uid)
            .updateData([
                "avatarAssetName": nomeAsset,
                "fotoData": FieldValue.delete()
            ])
    }

    func atualizarFoto(
        uid: String,
        dados: Data,
        conclusao: @escaping (String?) -> Void
    ) {
        guard let foto = prepararFoto(dados) else {
            conclusao("Não foi possível processar a foto.")
            return
        }

        db.collection("users")
            .document(uid)
            .updateData([
                "fotoData": foto,
                "avatarAssetName": FieldValue.delete()
            ]) { erro in
                DispatchQueue.main.async {
                    conclusao(erro == nil ? nil : "Não foi possível salvar a foto.")
                }
            }
    }

    func removerImagemPerfil(uid: String) {
        db.collection("users")
            .document(uid)
            .updateData([
                "fotoData": FieldValue.delete(),
                "avatarAssetName": FieldValue.delete()
            ])
    }

    func temLocal(uid: String, localID: String) -> Bool {
        perfil(uid: uid).locaisTrabalhados.contains { $0.id == localID }
    }

    func alternarLocal(uid: String, local: LocalEncontrado) {
        var locais = perfil(uid: uid).locaisTrabalhados

        if let indice = locais.firstIndex(where: { $0.id == local.id }) {
            locais.remove(at: indice)
        } else {
            locais.append(LocalTrabalhado(local: local))
        }

        db.collection("users")
            .document(uid)
            .setData(
                ["locaisTrabalhados": locais.map { $0.firestoreData }],
                merge: true
            )
    }

    private func prepararFoto(_ dados: Data) -> Data? {
        guard let imagem = UIImage(data: dados) else { return nil }

        let tamanho = CGSize(width: 220, height: 220)
        let renderer = UIGraphicsImageRenderer(size: tamanho)

        let novaImagem = renderer.image { _ in
            let proporcao = max(
                tamanho.width / imagem.size.width,
                tamanho.height / imagem.size.height
            )

            let largura = imagem.size.width * proporcao
            let altura = imagem.size.height * proporcao
            let x = (tamanho.width - largura) / 2
            let y = (tamanho.height - altura) / 2

            imagem.draw(in: CGRect(x: x, y: y, width: largura, height: altura))
        }

        return novaImagem.jpegData(compressionQuality: 0.60)
    }
}

// MARK: - AVALIAÇÕES FIRESTORE

final class AvaliacoesStore: ObservableObject {
    @Published private(set) var avaliacoes: [AvaliacaoLocal] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func iniciar() {
        guard listener == nil else { return }

        listener = db.collection("reviews").addSnapshotListener { [weak self] snapshot, erro in
            guard let self, let documentos = snapshot?.documents, erro == nil else { return }

            let novas = documentos
                .compactMap { self.converter(documento: $0) }
                .sorted { $0.data > $1.data }

            DispatchQueue.main.async {
                self.avaliacoes = novas
            }
        }
    }

    func parar() {
        listener?.remove()
        listener = nil
        avaliacoes = []
    }

    func avaliacoes(do localID: String) -> [AvaliacaoLocal] {
        avaliacoes
            .filter { $0.localID == localID }
            .sorted { $0.data > $1.data }
    }

    func avaliacoesPublicas(doUsuario uid: String) -> [AvaliacaoLocal] {
        avaliacoes
            .filter { $0.publicAuthorUID == uid }
            .sorted { $0.data > $1.data }
    }

    func adicionar(
        local: LocalEncontrado,
        uid: String,
        estrelas: Int,
        comentario: String,
        categorias: [String],
        conclusao: @escaping (String?) -> Void
    ) {
        let reviewRef = db.collection("reviews").document()
        let id = reviewRef.documentID
        let data = Date()
        let avatarAnonimo = estrelas < 4 ? AvatarPadrao.aleatorio() : nil

        var dadosPublicos: [String: Any] = [
            "localID": local.id,
            "localNome": local.nome,
            "estrelas": estrelas,
            "comentario": comentario,
            "categorias": categorias,
            "data": Timestamp(date: data)
        ]

        if let avatarAnonimo {
            dadosPublicos["avatarAnonimoNome"] = avatarAnonimo
        }

        if estrelas >= 4 {
            dadosPublicos["publicAuthorUID"] = uid
        }

        var dadosPrivados: [String: Any] = [
            "localID": local.id,
            "localNome": local.nome,
            "estrelas": estrelas,
            "comentario": comentario,
            "categorias": categorias,
            "data": Timestamp(date: data)
        ]

        if let avatarAnonimo {
            dadosPrivados["avatarAnonimoNome"] = avatarAnonimo
        }

        let privadaRef = db
            .collection("users")
            .document(uid)
            .collection("myReviews")
            .document(id)

        let batch = db.batch()
        batch.setData(dadosPublicos, forDocument: reviewRef)
        batch.setData(dadosPrivados, forDocument: privadaRef)

        batch.commit { erro in
            DispatchQueue.main.async {
                conclusao(erro == nil ? nil : "Não foi possível publicar a avaliação.")
            }
        }
    }

    private func converter(documento: QueryDocumentSnapshot) -> AvaliacaoLocal? {
        let dados = documento.data()

        guard
            let localID = dados["localID"] as? String,
            let localNome = dados["localNome"] as? String,
            let estrelas = dados["estrelas"] as? Int,
            let comentario = dados["comentario"] as? String
        else {
            return nil
        }

        let categorias = dados["categorias"] as? [String] ?? []
        let avatarAnonimoNome = dados["avatarAnonimoNome"] as? String
        let data = (dados["data"] as? Timestamp)?.dateValue() ?? Date()
        let publicAuthorUID = dados["publicAuthorUID"] as? String

        return AvaliacaoLocal(
            id: documento.documentID,
            localID: localID,
            localNome: localNome,
            estrelas: estrelas,
            comentario: comentario,
            categorias: categorias,
            avatarAnonimoNome: avatarAnonimoNome,
            data: data,
            publicAuthorUID: publicAuthorUID
        )
    }
}

// MARK: - MINHAS AVALIAÇÕES

final class MinhasAvaliacoesModel: ObservableObject {
    @Published private(set) var avaliacoes: [AvaliacaoLocal] = []

    private var listener: ListenerRegistration?

    init(uid: String) {
        listener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("myReviews")
            .addSnapshotListener { [weak self] snapshot, erro in
                guard let self, let documentos = snapshot?.documents, erro == nil else { return }

                let novas = documentos.compactMap { documento -> AvaliacaoLocal? in
                    let dados = documento.data()

                    guard
                        let localID = dados["localID"] as? String,
                        let localNome = dados["localNome"] as? String,
                        let estrelas = dados["estrelas"] as? Int,
                        let comentario = dados["comentario"] as? String
                    else {
                        return nil
                    }

                    return AvaliacaoLocal(
                        id: documento.documentID,
                        localID: localID,
                        localNome: localNome,
                        estrelas: estrelas,
                        comentario: comentario,
                        categorias: dados["categorias"] as? [String] ?? [],
                        avatarAnonimoNome: dados["avatarAnonimoNome"] as? String,
                        data: (dados["data"] as? Timestamp)?.dateValue() ?? Date(),
                        publicAuthorUID: nil
                    )
                }
                .sorted { $0.data > $1.data }

                DispatchQueue.main.async {
                    self.avaliacoes = novas
                }
            }
    }

    deinit {
        listener?.remove()
    }
}

// MARK: - REAÇÕES FIRESTORE

final class ReacoesStore: ObservableObject {
    @Published private(set) var reacoes: [ReacaoAvaliacao] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func iniciar() {
        guard listener == nil else { return }

        listener = db.collection("reactions").addSnapshotListener { [weak self] snapshot, erro in
            guard let self, let documentos = snapshot?.documents, erro == nil else { return }

            let novas = documentos.compactMap { documento -> ReacaoAvaliacao? in
                let dados = documento.data()

                guard
                    let avaliacaoID = dados["reviewID"] as? String,
                    let userUID = dados["userUID"] as? String,
                    let tipoString = dados["tipo"] as? String,
                    let tipo = TipoReacao(rawValue: tipoString)
                else {
                    return nil
                }

                return ReacaoAvaliacao(
                    id: documento.documentID,
                    avaliacaoID: avaliacaoID,
                    userUID: userUID,
                    tipo: tipo
                )
            }

            DispatchQueue.main.async {
                self.reacoes = novas
            }
        }
    }

    func parar() {
        listener?.remove()
        listener = nil
        reacoes = []
    }

    func quantidade(avaliacaoID: String, tipo: TipoReacao) -> Int {
        reacoes.filter {
            $0.avaliacaoID == avaliacaoID && $0.tipo == tipo
        }.count
    }

    func reacaoDoUsuario(avaliacaoID: String, uid: String) -> TipoReacao? {
        reacoes.first {
            $0.avaliacaoID == avaliacaoID && $0.userUID == uid
        }?.tipo
    }

    func alternar(avaliacaoID: String, uid: String, tipo: TipoReacao) {
        let id = "\(avaliacaoID)_\(uid)"
        let ref = db.collection("reactions").document(id)
        let atual = reacaoDoUsuario(avaliacaoID: avaliacaoID, uid: uid)

        if atual == tipo {
            ref.delete()
            return
        }

        ref.setData([
            "reviewID": avaliacaoID,
            "userUID": uid,
            "tipo": tipo.rawValue,
            "data": Timestamp(date: Date())
        ])
    }
}

// MARK: - LOCALIZAÇÃO

final class LocalizacaoManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var localizacaoAtual: CLLocation?
    @Published var mensagem = ""

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func solicitarPermissao() {
        guard CLLocationManager.locationServicesEnabled() else {
            mensagem = "Os Serviços de Localização estão desativados."
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            atualizarLocalizacao()
        case .denied:
            mensagem = "Permita o acesso à localização nos Ajustes."
        case .restricted:
            mensagem = "O acesso à localização está restrito."
        @unknown default:
            break
        }
    }

    func atualizarLocalizacao() {
        if manager.authorizationStatus == .authorizedWhenInUse ||
            manager.authorizationStatus == .authorizedAlways {
            mensagem = ""
            manager.requestLocation()
        } else {
            solicitarPermissao()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied:
            DispatchQueue.main.async {
                self.mensagem = "Você ainda pode pesquisar locais sem compartilhar sua localização."
            }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let local = locations.last else { return }

        DispatchQueue.main.async {
            self.localizacaoAtual = local
            self.mensagem = ""
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let erro = error as? CLError, erro.code == .locationUnknown { return }

        DispatchQueue.main.async {
            self.mensagem = "Não foi possível obter sua localização."
        }
    }
}

// MARK: - PESQUISA MAPKIT

final class PesquisaLocaisModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var texto = "" {
        didSet { atualizarPesquisa() }
    }

    @Published var sugestoes: [MKLocalSearchCompletion] = []
    @Published var carregando = false
    @Published var mensagemErro = ""

    private let completer = MKLocalSearchCompleter()
    private var buscaAtual: MKLocalSearch?

    private var regiaoPesquisa = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -14.235, longitude: -51.9253),
        span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 40)
    )

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
        completer.region = regiaoPesquisa
    }

    func atualizarRegiao(com coordenada: CLLocationCoordinate2D) {
        regiaoPesquisa = MKCoordinateRegion(
            center: coordenada,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        completer.region = regiaoPesquisa
    }

    private func atualizarPesquisa() {
        let termo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        mensagemErro = ""

        if termo.count < 2 {
            sugestoes = []
            completer.queryFragment = ""
            return
        }

        completer.queryFragment = termo
    }

    func limpar() {
        texto = ""
        sugestoes = []
        mensagemErro = ""
        completer.cancel()
        buscaAtual?.cancel()
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.sugestoes = Array(completer.results.prefix(7))
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.mensagemErro = "Não foi possível buscar locais."
        }
    }

    func resolver(
        _ sugestao: MKLocalSearchCompletion,
        conclusao: @escaping (LocalEncontrado?) -> Void
    ) {
        carregando = true
        mensagemErro = ""
        buscaAtual?.cancel()

        let request = MKLocalSearch.Request(completion: sugestao)
        request.region = regiaoPesquisa
        request.resultTypes = [.pointOfInterest, .address]

        let busca = MKLocalSearch(request: request)
        buscaAtual = busca

        busca.start { response, erro in
            DispatchQueue.main.async {
                self.carregando = false

                guard erro == nil, let item = response?.mapItems.first else {
                    self.mensagemErro = "Não foi possível encontrar este local."
                    conclusao(nil)
                    return
                }

                let local = LocalEncontrado(mapItem: item)
                self.texto = local.nome
                self.sugestoes = []
                conclusao(local)
            }
        }
    }

    func pesquisarTextoDigitado(
        conclusao: @escaping (LocalEncontrado?) -> Void
    ) {
        let termo = texto.trimmingCharacters(in: .whitespacesAndNewlines)

        guard termo.count >= 2 else {
            mensagemErro = "Digite o nome de uma empresa ou local."
            return
        }

        carregando = true
        mensagemErro = ""

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = termo
        request.region = regiaoPesquisa
        request.resultTypes = [.pointOfInterest, .address]

        let busca = MKLocalSearch(request: request)
        buscaAtual = busca

        busca.start { response, erro in
            DispatchQueue.main.async {
                self.carregando = false

                guard erro == nil, let item = response?.mapItems.first else {
                    self.mensagemErro = "Nenhum local encontrado."
                    conclusao(nil)
                    return
                }

                self.sugestoes = []
                conclusao(LocalEncontrado(mapItem: item))
            }
        }
    }
}

// MARK: - MAPA PRINCIPAL

struct MapaPrincipalView: UIViewRepresentable {
    let localizacaoUsuario: CLLocation?
    let localSelecionado: LocalEncontrado?
    let centralizarToken: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let mapa = MKMapView()
        mapa.mapType = .mutedStandard
        mapa.showsUserLocation = true
        mapa.showsCompass = true
        mapa.isZoomEnabled = true
        mapa.isScrollEnabled = true
        return mapa
    }

    func updateUIView(_ mapa: MKMapView, context: Context) {
        mapa.showsUserLocation = true

        mapa.removeAnnotations(
            mapa.annotations.filter { !($0 is MKUserLocation) }
        )

        if let local = localSelecionado {
            let coordenada = CLLocationCoordinate2D(
                latitude: local.latitude,
                longitude: local.longitude
            )

            let pin = MKPointAnnotation()
            pin.coordinate = coordenada
            pin.title = local.nome
            mapa.addAnnotation(pin)

            if context.coordinator.ultimoLocalID != local.id {
                context.coordinator.ultimoLocalID = local.id

                mapa.setRegion(
                    MKCoordinateRegion(
                        center: coordenada,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ),
                    animated: true
                )
            }
            return
        }

        if let localizacao = localizacaoUsuario,
           !context.coordinator.jaCentralizou || context.coordinator.ultimoToken != centralizarToken {
            context.coordinator.jaCentralizou = true
            context.coordinator.ultimoToken = centralizarToken
            context.coordinator.ultimoLocalID = nil

            mapa.setRegion(
                MKCoordinateRegion(
                    center: localizacao.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                ),
                animated: true
            )
        }
    }

    final class Coordinator {
        var jaCentralizou = false
        var ultimoToken = 0
        var ultimoLocalID: String?
    }
}

// MARK: - MAPA LOCAL

struct AppleMapLocalView: UIViewRepresentable {
    let local: LocalEncontrado

    func makeUIView(context: Context) -> MKMapView {
        let mapa = MKMapView()
        mapa.isZoomEnabled = true
        mapa.isScrollEnabled = true
        return mapa
    }

    func updateUIView(_ mapa: MKMapView, context: Context) {
        let coordenada = CLLocationCoordinate2D(
            latitude: local.latitude,
            longitude: local.longitude
        )

        mapa.removeAnnotations(mapa.annotations)

        let pin = MKPointAnnotation()
        pin.coordinate = coordenada
        pin.title = local.nome
        mapa.addAnnotation(pin)

        mapa.setRegion(
            MKCoordinateRegion(
                center: coordenada,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            ),
            animated: true
        )
    }
}

// MARK: - FUNDO LOGIN

struct FundoCircular<Conteudo: View>: View {
    let conteudo: Conteudo

    init(@ViewBuilder conteudo: () -> Conteudo) {
        self.conteudo = conteudo()
    }

    var body: some View {
        ZStack {
            Color.pink.ignoresSafeArea()

            GeometryReader { tela in
                let largura = tela.size.width
                let altura = tela.size.height
                let larguraFormulario = min(largura - 56, 340)
                let tamanhoCirculo = max(largura * 1.45, 560)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: tamanhoCirculo + 34, height: tamanhoCirculo + 34)
                        .position(x: largura / 2, y: altura / 2)

                    Circle()
                        .fill(Color.white)
                        .frame(width: tamanhoCirculo, height: tamanhoCirculo)
                        .position(x: largura / 2, y: altura / 2)

                    ScrollView {
                        VStack {
                            conteudo.frame(width: larguraFormulario)
                        }
                        .frame(width: largura)
                        .frame(minHeight: altura)
                    }
                    .frame(width: largura, height: altura)
                    .scrollDismissesKeyboard(.interactively)
                }
                .frame(width: largura, height: altura)
                .clipped()
            }
        }
    }
}

// MARK: - AVATAR DO PERFIL

struct AvatarPerfilView: View {
    let perfil: PerfilUsuario
    var tamanho: CGFloat = 48

    var body: some View {
        ZStack {
            Circle()
                .fill(perfil.corPerfil.cor.opacity(0.15))

            if let dados = perfil.fotoData,
               let imagem = UIImage(data: dados) {
                Image(uiImage: imagem)
                    .resizable()
                    .scaledToFill()
                    .frame(width: tamanho, height: tamanho)
                    .clipShape(Circle())
            } else if let asset = perfil.avatarAssetName {
                Image(asset)
                    .resizable()
                    .scaledToFill()
                    .frame(width: tamanho, height: tamanho)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: tamanho * 0.42))
                    .foregroundColor(perfil.corPerfil.cor)
            }
        }
        .frame(width: tamanho, height: tamanho)
        .overlay(
            Circle().stroke(
                perfil.corPerfil.cor,
                lineWidth: max(2, tamanho * 0.05)
            )
        )
        .clipShape(Circle())
    }
}

struct AvatarAnonimoView: View {
    let nomeAsset: String
    var tamanho: CGFloat = 40

    var body: some View {
        Image(nomeAsset)
            .resizable()
            .scaledToFill()
            .frame(width: tamanho, height: tamanho)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.pink.opacity(0.45), lineWidth: 2)
            )
    }
}

// MARK: - CONTENT VIEW

struct ContentView: View {
    @StateObject private var auth = FirebaseAuthStore()
    @StateObject private var perfilStore = PerfilStore()
    @StateObject private var avaliacoesStore = AvaliacoesStore()
    @StateObject private var reacoesStore = ReacoesStore()

    var body: some View {
        Group {
            if let usuario = auth.usuarioAtual {
                NavigationStack {
                    if auth.mostrarBoasVindas {
                        BoasVindasView(auth: auth)
                    } else {
                        HomeView(
                            auth: auth,
                            uid: usuario.uid,
                            email: usuario.email ?? "",
                            perfilStore: perfilStore,
                            avaliacoesStore: avaliacoesStore,
                            reacoesStore: reacoesStore
                        )
                    }
                }
            } else {
                NavigationStack {
                    LoginView(auth: auth)
                }
            }
        }
        .onReceive(auth.$usuarioAtual) { usuario in
            if usuario != nil {
                perfilStore.iniciar()
                avaliacoesStore.iniciar()
                reacoesStore.iniciar()
            } else {
                perfilStore.parar()
                avaliacoesStore.parar()
                reacoesStore.parar()
            }
        }
    }
}

// MARK: - LOGIN

struct LoginView: View {
    @ObservedObject var auth: FirebaseAuthStore

    @State private var email = ""
    @State private var senha = ""

    var body: some View {
        FundoCircular {
            VStack(spacing: 15) {
                Text("JobRate")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.pink)

                Text("Entre na sua conta")
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)

                TextField("E-mail", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .frame(height: 52)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)

                SecureField("Senha", text: $senha)
                    .padding()
                    .frame(height: 52)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)

                if !auth.mensagemErro.isEmpty {
                    Text(auth.mensagemErro)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button {
                    auth.entrar(email: email, senha: senha)
                } label: {
                    if auth.carregando {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    } else {
                        Text("Entrar")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                }
                .foregroundColor(.white)
                .background(Color.pink)
                .cornerRadius(12)
                .disabled(auth.carregando)

                NavigationLink {
                    CadastroView(auth: auth)
                } label: {
                    Text("Criar conta")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .foregroundColor(.pink)
                .background(Color.pink.opacity(0.10))
                .cornerRadius(12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - CADASTRO

struct CadastroView: View {
    @ObservedObject var auth: FirebaseAuthStore

    @State private var apelido = ""
    @State private var email = ""
    @State private var senha = ""
    @State private var confirmarSenha = ""

    var body: some View {
        FundoCircular {
            VStack(spacing: 15) {
                Text("Criar conta")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.pink)

                Text("Cadastre-se no JobRate")
                    .foregroundColor(.secondary)
                    .padding(.bottom, 12)

                TextField("Apelido", text: $apelido)
                    .textInputAutocapitalization(.words)
                    .padding()
                    .frame(height: 52)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)

                TextField("E-mail", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .frame(height: 52)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)

                SecureField("Senha", text: $senha)
                    .padding()
                    .frame(height: 52)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)

                SecureField("Confirmar senha", text: $confirmarSenha)
                    .padding()
                    .frame(height: 52)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)

                if !auth.mensagemErro.isEmpty {
                    Text(auth.mensagemErro)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button {
                    auth.cadastrar(
                        apelido: apelido,
                        email: email,
                        senha: senha,
                        confirmarSenha: confirmarSenha
                    )
                } label: {
                    if auth.carregando {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    } else {
                        Text("Cadastrar")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                }
                .foregroundColor(.white)
                .background(Color.pink)
                .cornerRadius(12)
                .disabled(auth.carregando)
            }
        }
        .navigationTitle("Cadastro")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.pink)
    }
}

// MARK: - BOAS-VINDAS

struct BoasVindasView: View {
    @ObservedObject var auth: FirebaseAuthStore

    var body: some View {
        ZStack {
            Color.pink.opacity(0.06).ignoresSafeArea()

            VStack(spacing: 25) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 60))
                    .foregroundColor(.pink)

                Text("Bem-vindo(a) ao JobRate!")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Pesquise locais, compartilhe experiências e veja avaliações de outros usuários.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    auth.continuarParaApp()
                } label: {
                    Text("Abrir mapa")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                }
                .foregroundColor(.white)
                .background(Color.pink)
                .cornerRadius(15)
            }
            .padding(25)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - HOME

struct HomeView: View {
    @ObservedObject var auth: FirebaseAuthStore

    let uid: String
    let email: String

    @ObservedObject var perfilStore: PerfilStore
    @ObservedObject var avaliacoesStore: AvaliacoesStore
    @ObservedObject var reacoesStore: ReacoesStore

    @StateObject private var pesquisa = PesquisaLocaisModel()
    @StateObject private var localizacao = LocalizacaoManager()

    @State private var localSelecionado: LocalEncontrado?
    @State private var abrirDetalhe = false
    @State private var centralizarToken = 0

    private var perfil: PerfilUsuario {
        perfilStore.perfil(uid: uid)
    }

    var body: some View {
        ZStack {
            MapaPrincipalView(
                localizacaoUsuario: localizacao.localizacaoAtual,
                localSelecionado: localSelecionado,
                centralizarToken: centralizarToken
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("JobRate")
                        .font(.title2)
                        .bold()

                    Spacer()

                    NavigationLink {
                        PerfilView(
                            uid: uid,
                            email: email,
                            auth: auth,
                            perfilStore: perfilStore,
                            reacoesStore: reacoesStore
                        )
                    } label: {
                        AvatarPerfilView(perfil: perfil, tamanho: 42)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                HStack {
                    Spacer()

                    Button {
                        centralizarToken += 1
                        localizacao.atualizarLocalizacao()
                    } label: {
                        Image(systemName: "location.fill")
                            .foregroundColor(.pink)
                            .frame(width: 50, height: 50)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 6)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Onde você trabalhou?")
                        .font(.system(size: 25, weight: .bold))

                    Text("Pesquise uma empresa ou estabelecimento")
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("Buscar local", text: $pesquisa.texto)
                            .submitLabel(.search)
                            .onSubmit {
                                pesquisa.pesquisarTextoDigitado { local in
                                    selecionar(local)
                                }
                            }

                        if !pesquisa.texto.isEmpty {
                            Button {
                                pesquisa.limpar()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.10))
                    .cornerRadius(14)

                    if pesquisa.carregando {
                        ProgressView("Localizando...")
                    }

                    if !pesquisa.mensagemErro.isEmpty {
                        Text(pesquisa.mensagemErro)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if !pesquisa.sugestoes.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(pesquisa.sugestoes.enumerated()), id: \.offset) { indice, sugestao in
                                    Button {
                                        pesquisa.resolver(sugestao) { local in
                                            selecionar(local)
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(.pink)

                                            VStack(alignment: .leading) {
                                                Text(sugestao.title)
                                                    .bold()
                                                    .foregroundColor(.primary)

                                                if !sugestao.subtitle.isEmpty {
                                                    Text(sugestao.subtitle)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }

                                            Spacer()
                                        }
                                        .padding(.vertical, 10)
                                    }

                                    if indice < pesquisa.sugestoes.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                    }
                }
                .padding(22)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(color: Color.black.opacity(0.12), radius: 15, y: -3)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            localizacao.solicitarPermissao()
        }
        .onReceive(localizacao.$localizacaoAtual) { local in
            if let coordenada = local?.coordinate {
                pesquisa.atualizarRegiao(com: coordenada)
            }
        }
        .navigationDestination(isPresented: $abrirDetalhe) {
            if let local = localSelecionado {
                DetalheLocalView(
                    local: local,
                    uid: uid,
                    perfilStore: perfilStore,
                    avaliacoesStore: avaliacoesStore,
                    reacoesStore: reacoesStore
                )
            }
        }
    }

    private func selecionar(_ local: LocalEncontrado?) {
        guard let local else { return }
        localSelecionado = local
        abrirDetalhe = true
    }
}

// MARK: - PERFIL PRÓPRIO

struct PerfilView: View {
    let uid: String
    let email: String

    @ObservedObject var auth: FirebaseAuthStore
    @ObservedObject var perfilStore: PerfilStore
    @ObservedObject var reacoesStore: ReacoesStore

    @StateObject private var minhasAvaliacoes: MinhasAvaliacoesModel

    @State private var fotoSelecionada: PhotosPickerItem?
    @State private var apelidoEdicao = ""
    @State private var mensagem = ""

    init(
        uid: String,
        email: String,
        auth: FirebaseAuthStore,
        perfilStore: PerfilStore,
        reacoesStore: ReacoesStore
    ) {
        self.uid = uid
        self.email = email
        self.auth = auth
        self.perfilStore = perfilStore
        self.reacoesStore = reacoesStore
        _minhasAvaliacoes = StateObject(wrappedValue: MinhasAvaliacoesModel(uid: uid))
    }

    private var perfil: PerfilUsuario {
        perfilStore.perfil(uid: uid)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 14) {
                    AvatarPerfilView(perfil: perfil, tamanho: 110)

                    Text(perfil.nomeExibicao)
                        .font(.title2)
                        .bold()

                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    PhotosPicker(selection: $fotoSelecionada, matching: .images) {
                        Label("Escolher foto da galeria", systemImage: "photo.fill")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                    }
                    .foregroundColor(perfil.corPerfil.cor)
                    .background(perfil.corPerfil.cor.opacity(0.10))
                    .cornerRadius(12)

                    if perfil.fotoData != nil || perfil.avatarAssetName != nil {
                        Button("Remover imagem do perfil") {
                            perfilStore.removerImagemPerfil(uid: uid)
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Avatares do JobRate")
                        .font(.headline)

                    Text("Escolha um avatar ou use uma foto da sua galeria.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(AvatarPadrao.todos) { avatar in
                                Button {
                                    perfilStore.atualizarAvatarPadrao(
                                        uid: uid,
                                        nomeAsset: avatar.nomeAsset
                                    )
                                } label: {
                                    ZStack(alignment: .bottomTrailing) {
                                        Image(avatar.nomeAsset)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 75, height: 75)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle().stroke(
                                                    perfil.avatarAssetName == avatar.nomeAsset
                                                        ? perfil.corPerfil.cor
                                                        : Color.gray.opacity(0.20),
                                                    lineWidth: perfil.avatarAssetName == avatar.nomeAsset ? 4 : 1
                                                )
                                            )

                                        if perfil.avatarAssetName == avatar.nomeAsset {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(perfil.corPerfil.cor)
                                                .background(Color.white.clipShape(Circle()))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(18)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Apelido")
                        .font(.headline)

                    TextField("Seu apelido", text: $apelidoEdicao)
                        .padding()
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(12)

                    Button {
                        perfilStore.atualizarApelido(uid: uid, apelido: apelidoEdicao) { erro in
                            mensagem = erro ?? "Apelido salvo!"
                        }
                    } label: {
                        Text("Salvar apelido")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .foregroundColor(.white)
                    .background(perfil.corPerfil.cor)
                    .cornerRadius(12)

                    if !mensagem.isEmpty {
                        Text(mensagem)
                            .font(.caption)
                            .foregroundColor(mensagem == "Apelido salvo!" ? .green : .red)
                    }
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(18)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Cor do perfil")
                        .font(.headline)

                    HStack(spacing: 18) {
                        ForEach(CorPerfil.allCases) { cor in
                            Button {
                                perfilStore.atualizarCor(uid: uid, cor: cor)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(cor.cor)
                                        .frame(width: 42, height: 42)

                                    if perfil.corPerfil == cor {
                                        Image(systemName: "checkmark")
                                            .bold()
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(18)

                HStack(spacing: 14) {
                    NumeroPerfilCard(
                        numero: minhasAvaliacoes.avaliacoes.count,
                        titulo: "Avaliações",
                        icone: "star.fill",
                        cor: perfil.corPerfil.cor
                    )

                    NumeroPerfilCard(
                        numero: perfil.locaisTrabalhados.count,
                        titulo: "Locais",
                        icone: "building.2.fill",
                        cor: perfil.corPerfil.cor
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Onde trabalhei")
                        .font(.title2)
                        .bold()

                    if perfil.locaisTrabalhados.isEmpty {
                        Text("Você ainda não adicionou nenhum local.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(perfil.locaisTrabalhados) { local in
                            LocalPerfilCard(local: local, cor: perfil.corPerfil.cor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Minhas avaliações")
                        .font(.title2)
                        .bold()

                    if minhasAvaliacoes.avaliacoes.isEmpty {
                        Text("Você ainda não publicou avaliações.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(minhasAvaliacoes.avaliacoes) { avaliacao in
                            MinhaAvaliacaoCard(
                                avaliacao: avaliacao,
                                cor: perfil.corPerfil.cor,
                                reacoesStore: reacoesStore
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(role: .destructive) {
                    auth.sair()
                } label: {
                    Label("Sair da conta", systemImage: "rectangle.portrait.and.arrow.right")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .background(Color.red.opacity(0.08))
                .cornerRadius(14)
            }
            .padding(20)
        }
        .background(perfil.corPerfil.cor.opacity(0.05))
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            apelidoEdicao = perfil.apelido
        }
        .onChange(of: fotoSelecionada) { novoItem in
            guard let novoItem else { return }

            Task {
                if let dados = try? await novoItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        perfilStore.atualizarFoto(uid: uid, dados: dados) { erro in
                            if let erro {
                                mensagem = erro
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - PERFIL PÚBLICO

struct PerfilPublicoView: View {
    let uid: String

    @ObservedObject var perfilStore: PerfilStore
    @ObservedObject var avaliacoesStore: AvaliacoesStore
    @ObservedObject var reacoesStore: ReacoesStore

    private var perfil: PerfilUsuario {
        perfilStore.perfil(uid: uid)
    }

    private var avaliacoes: [AvaliacaoLocal] {
        avaliacoesStore.avaliacoesPublicas(doUsuario: uid)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                AvatarPerfilView(perfil: perfil, tamanho: 110)

                Text(perfil.nomeExibicao)
                    .font(.title)
                    .bold()

                HStack(spacing: 14) {
                    NumeroPerfilCard(
                        numero: avaliacoes.count,
                        titulo: "Avaliações",
                        icone: "star.fill",
                        cor: perfil.corPerfil.cor
                    )

                    NumeroPerfilCard(
                        numero: perfil.locaisTrabalhados.count,
                        titulo: "Locais",
                        icone: "building.2.fill",
                        cor: perfil.corPerfil.cor
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Onde trabalhou")
                        .font(.title2)
                        .bold()

                    if perfil.locaisTrabalhados.isEmpty {
                        Text("Nenhum local adicionado.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(perfil.locaisTrabalhados) { local in
                            LocalPerfilCard(local: local, cor: perfil.corPerfil.cor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Avaliações")
                        .font(.title2)
                        .bold()

                    if avaliacoes.isEmpty {
                        Text("Nenhuma avaliação pública.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(avaliacoes) { avaliacao in
                            MinhaAvaliacaoCard(
                                avaliacao: avaliacao,
                                cor: perfil.corPerfil.cor,
                                reacoesStore: reacoesStore
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .background(perfil.corPerfil.cor.opacity(0.05))
        .navigationTitle(perfil.nomeExibicao)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - DETALHE LOCAL

struct DetalheLocalView: View {
    let local: LocalEncontrado
    let uid: String

    @ObservedObject var perfilStore: PerfilStore
    @ObservedObject var avaliacoesStore: AvaliacoesStore
    @ObservedObject var reacoesStore: ReacoesStore

    @State private var filtro: FiltroAvaliacao = .todas

    private var todas: [AvaliacaoLocal] {
        avaliacoesStore.avaliacoes(do: local.id)
    }

    private var boas: [AvaliacaoLocal] {
        todas.filter { $0.estrelas >= 4 }
    }

    private var ruins: [AvaliacaoLocal] {
        todas.filter { $0.estrelas <= 2 }
    }

    private var filtradas: [AvaliacaoLocal] {
        switch filtro {
        case .todas: return todas
        case .boas: return boas
        case .ruins: return ruins
        }
    }

    private var media: Double {
        guard !todas.isEmpty else { return 0 }
        let total = todas.reduce(0) { $0 + $1.estrelas }
        return Double(total) / Double(todas.count)
    }

    private var reputacao: Double { media / 5 }

    private var textoReputacao: String {
        if todas.isEmpty { return "Sem avaliações" }
        if media >= 4.5 { return "Excelente" }
        if media >= 4 { return "Muito boa" }
        if media >= 3 { return "Regular" }
        if media >= 2 { return "Ruim" }
        return "Muito ruim"
    }

    private var corReputacao: Color {
        if todas.isEmpty { return .gray }
        if media >= 4 { return .green }
        if media >= 3 { return .orange }
        return .red
    }

    private var localAdicionado: Bool {
        perfilStore.temLocal(uid: uid, localID: local.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                AppleMapLocalView(local: local)
                    .frame(height: 235)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Text(local.nome)
                    .font(.title)
                    .bold()

                Label(local.endereco, systemImage: "mappin.and.ellipse")
                    .foregroundColor(.secondary)

                Button {
                    perfilStore.alternarLocal(uid: uid, local: local)
                } label: {
                    Label(
                        localAdicionado
                            ? "Local adicionado ao meu perfil"
                            : "Adicionar aos locais onde trabalhei",
                        systemImage: localAdicionado
                            ? "checkmark.circle.fill"
                            : "briefcase.fill"
                    )
                    .bold()
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .foregroundColor(localAdicionado ? .green : .pink)
                .background((localAdicionado ? Color.green : Color.pink).opacity(0.10))
                .cornerRadius(14)

                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Reputação")
                                .font(.headline)

                            Text(textoReputacao)
                                .font(.title2)
                                .bold()
                                .foregroundColor(corReputacao)
                        }

                        Spacer()

                        if !todas.isEmpty {
                            Text("\(Int((reputacao * 100).rounded()))%")
                                .font(.title)
                                .bold()
                        }
                    }

                    ProgressView(value: reputacao)
                        .tint(corReputacao)
                        .scaleEffect(x: 1, y: 2.2, anchor: .center)

                    HStack {
                        Label("\(boas.count) boas", systemImage: "hand.thumbsup.fill")
                            .font(.caption)
                            .foregroundColor(.green)

                        Spacer()

                        Label("\(ruins.count) ruins", systemImage: "hand.thumbsdown.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(18)

                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nota geral")
                            .font(.headline)

                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { estrela in
                                Image(systemName: Double(estrela) <= media ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(todas.isEmpty ? "--" : String(format: "%.1f", media))
                            .font(.title)
                            .bold()

                        Text("\(todas.count) avaliações")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                NavigationLink {
                    AvaliarLocalView(
                        local: local,
                        uid: uid,
                        avaliacoesStore: avaliacoesStore
                    )
                } label: {
                    Label("Avaliar este local", systemImage: "star.bubble.fill")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                }
                .foregroundColor(.white)
                .background(Color.pink)
                .cornerRadius(15)

                Divider()

                Text("Experiências")
                    .font(.title2)
                    .bold()

                Picker("Filtro", selection: $filtro) {
                    ForEach(FiltroAvaliacao.allCases) { filtro in
                        Text(filtro.rawValue).tag(filtro)
                    }
                }
                .pickerStyle(.segmented)

                if filtradas.isEmpty {
                    Text("Nenhuma avaliação encontrada.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(30)
                } else {
                    ForEach(filtradas) { avaliacao in
                        AvaliacaoCard(
                            avaliacao: avaliacao,
                            uid: uid,
                            perfilStore: perfilStore,
                            avaliacoesStore: avaliacoesStore,
                            reacoesStore: reacoesStore
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(Color.pink.opacity(0.04))
        .navigationTitle("Local")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - NOVA AVALIAÇÃO

struct AvaliarLocalView: View {
    let local: LocalEncontrado
    let uid: String

    @ObservedObject var avaliacoesStore: AvaliacoesStore

    @Environment(\.dismiss) private var dismiss

    @State private var estrelas = 0
    @State private var comentario = ""
    @State private var categoriasSelecionadas: Set<String> = []
    @State private var erro = ""
    @State private var enviando = false

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
            VStack(alignment: .leading, spacing: 22) {
                Text(local.nome)
                    .font(.title2)
                    .bold()

                Text("Como foi sua experiência?")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { estrela in
                        Button {
                            estrelas = estrela
                        } label: {
                            Image(systemName: estrela <= estrelas ? "star.fill" : "star")
                                .font(.system(size: 34))
                                .foregroundColor(.yellow)
                        }
                    }
                }

                Divider()

                Text("O que se relaciona à sua experiência?")
                    .font(.headline)

                Text("Você pode marcar mais de uma opção.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(categorias, id: \.self) { categoria in
                    Button {
                        if categoriasSelecionadas.contains(categoria) {
                            categoriasSelecionadas.remove(categoria)
                        } else {
                            categoriasSelecionadas.insert(categoria)
                        }
                    } label: {
                        HStack {
                            Image(
                                systemName: categoriasSelecionadas.contains(categoria)
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .foregroundColor(.pink)

                            Text(categoria)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                Text("Conte sua experiência")
                    .font(.headline)

                Text("Evite publicar nomes, telefones ou dados pessoais de outras pessoas.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $comentario)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(12)

                if !erro.isEmpty {
                    Text(erro)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button {
                    publicar()
                } label: {
                    if enviando {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                    } else {
                        Label("Publicar avaliação", systemImage: "paperplane.fill")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                    }
                }
                .foregroundColor(.white)
                .background(Color.pink)
                .cornerRadius(15)
                .disabled(enviando)
            }
            .padding(20)
        }
        .background(Color.pink.opacity(0.04))
        .navigationTitle("Nova avaliação")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func publicar() {
        erro = ""

        let texto = comentario.trimmingCharacters(in: .whitespacesAndNewlines)

        guard estrelas > 0 else {
            erro = "Escolha de 1 a 5 estrelas."
            return
        }

        guard !texto.isEmpty else {
            erro = "Escreva um comentário."
            return
        }

        enviando = true

        avaliacoesStore.adicionar(
            local: local,
            uid: uid,
            estrelas: estrelas,
            comentario: texto,
            categorias: Array(categoriasSelecionadas).sorted()
        ) { erroFirebase in
            enviando = false

            if let erroFirebase {
                erro = erroFirebase
            } else {
                dismiss()
            }
        }
    }
}

// MARK: - CARD DE AVALIAÇÃO

struct AvaliacaoCard: View {
    let avaliacao: AvaliacaoLocal
    let uid: String

    @ObservedObject var perfilStore: PerfilStore
    @ObservedObject var avaliacoesStore: AvaliacoesStore
    @ObservedObject var reacoesStore: ReacoesStore

    private var positiva: Bool { avaliacao.estrelas >= 4 }
    private var negativa: Bool { avaliacao.estrelas <= 2 }

    private var minhaReacao: TipoReacao? {
        reacoesStore.reacaoDoUsuario(avaliacaoID: avaliacao.id, uid: uid)
    }

    private var concordam: Int {
        reacoesStore.quantidade(avaliacaoID: avaliacao.id, tipo: .concordar)
    }

    private var discordam: Int {
        reacoesStore.quantidade(avaliacaoID: avaliacao.id, tipo: .discordar)
    }

    private var avatarAnonimo: String {
        avaliacao.avatarAnonimoNome ?? AvatarPadrao.baseadoNoID(avaliacao.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                if positiva, let autorUID = avaliacao.publicAuthorUID {
                    let perfil = perfilStore.perfil(uid: autorUID)

                    NavigationLink {
                        PerfilPublicoView(
                            uid: autorUID,
                            perfilStore: perfilStore,
                            avaliacoesStore: avaliacoesStore,
                            reacoesStore: reacoesStore
                        )
                    } label: {
                        HStack(spacing: 10) {
                            AvatarPerfilView(perfil: perfil, tamanho: 40)

                            Text(perfil.nomeExibicao)
                                .font(.headline)
                                .foregroundColor(.primary)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    AvatarAnonimoView(nomeAsset: avatarAnonimo, tamanho: 42)

                    Text("Anônimo")
                        .font(.headline)
                }

                Spacer()

                if positiva {
                    Label("Positiva", systemImage: "hand.thumbsup.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if negativa {
                    Label("Negativa", systemImage: "hand.thumbsdown.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("Neutra")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            EstrelasView(quantidade: avaliacao.estrelas)

            if !avaliacao.categorias.isEmpty {
                ForEach(avaliacao.categorias, id: \.self) { categoria in
                    Label(categoria, systemImage: "tag.fill")
                        .font(.caption)
                        .foregroundColor(.pink)
                }
            }

            Text(avaliacao.comentario)

            Divider()

            HStack(spacing: 10) {
                BotaoReacao(
                    titulo: "Concordar",
                    icone: "hand.thumbsup",
                    quantidade: concordam,
                    selecionado: minhaReacao == .concordar,
                    cor: .green
                ) {
                    reacoesStore.alternar(
                        avaliacaoID: avaliacao.id,
                        uid: uid,
                        tipo: .concordar
                    )
                }

                BotaoReacao(
                    titulo: "Discordar",
                    icone: "hand.thumbsdown",
                    quantidade: discordam,
                    selecionado: minhaReacao == .discordar,
                    cor: .red
                ) {
                    reacoesStore.alternar(
                        avaliacaoID: avaliacao.id,
                        uid: uid,
                        tipo: .discordar
                    )
                }
            }

            Text(avaliacao.data.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 7, y: 3)
    }
}

// MARK: - BOTÃO REAÇÃO

struct BotaoReacao: View {
    let titulo: String
    let icone: String
    let quantidade: Int
    let selecionado: Bool
    let cor: Color
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            HStack(spacing: 5) {
                Image(systemName: selecionado ? "\(icone).fill" : icone)
                Text(titulo)
                Text("\(quantidade)")
            }
            .font(.caption)
            .bold()
            .foregroundColor(selecionado ? .white : cor)
            .padding(.horizontal, 11)
            .frame(height: 38)
            .background(selecionado ? cor : cor.opacity(0.10))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ESTRELAS

struct EstrelasView: View {
    let quantidade: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { estrela in
                Image(systemName: estrela <= quantidade ? "star.fill" : "star")
                    .foregroundColor(.yellow)
            }
        }
    }
}

// MARK: - CARD NUMÉRICO DO PERFIL

struct NumeroPerfilCard: View {
    let numero: Int
    let titulo: String
    let icone: String
    let cor: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icone)
                .foregroundColor(cor)

            Text("\(numero)")
                .font(.title2)
                .bold()

            Text(titulo)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.white)
        .cornerRadius(16)
    }
}

// MARK: - LOCAL NO PERFIL

struct LocalPerfilCard: View {
    let local: LocalTrabalhado
    let cor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "building.2.fill")
                .foregroundColor(cor)

            VStack(alignment: .leading, spacing: 4) {
                Text(local.nome)
                    .bold()

                Text(local.endereco)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
    }
}

// MARK: - AVALIAÇÃO NO PERFIL

struct MinhaAvaliacaoCard: View {
    let avaliacao: AvaliacaoLocal
    let cor: Color

    @ObservedObject var reacoesStore: ReacoesStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(avaliacao.localNome)
                .bold()
                .foregroundColor(cor)

            EstrelasView(quantidade: avaliacao.estrelas)

            if !avaliacao.categorias.isEmpty {
                ForEach(avaliacao.categorias, id: \.self) { categoria in
                    Label(categoria, systemImage: "tag.fill")
                        .font(.caption)
                        .foregroundColor(.pink)
                }
            }

            Text(avaliacao.comentario)

            HStack {
                Label(
                    "\(reacoesStore.quantidade(avaliacaoID: avaliacao.id, tipo: .concordar))",
                    systemImage: "hand.thumbsup.fill"
                )

                Label(
                    "\(reacoesStore.quantidade(avaliacaoID: avaliacao.id, tipo: .discordar))",
                    systemImage: "hand.thumbsdown.fill"
                )

                Spacer()

                Text(avaliacao.data.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
    }
}

