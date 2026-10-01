
//
//  ContentView.swift
//  JobRate
//
//  Created by Vitoria Carlosso on 28/09/26.
//

import SwiftUI
import Combine
import Security

// MARK: - DADOS DA CONTA

struct ContaLocal: Codable, Identifiable {

    var email: String

    var id: String {
        email
    }
}

// MARK: - SISTEMA DE LOGIN E CADASTRO

class LocalAuthStore: ObservableObject {

    @Published var usuarioAtual: ContaLocal?
    @Published var mensagemErro = ""

    private var contas: [ContaLocal] = []

    private let contasKey = "jobrate.contas"
    private let sessaoKey = "jobrate.sessao"
    private let servico = "jobrate.senhas"

    init() {

        // Recuperar contas salvas no aparelho

        if let dados = UserDefaults.standard.data(forKey: contasKey),
           let contasSalvas = try? JSONDecoder().decode(
                [ContaLocal].self,
                from: dados
           ) {

            contas = contasSalvas
        }

        // Recuperar a sessão anterior

        if let email = UserDefaults.standard.string(forKey: sessaoKey) {

            usuarioAtual = contas.first {
                $0.email == email
            }
        }
    }

    // MARK: - CRIAR CONTA

    func cadastrar(
        email: String,
        senha: String,
        confirmarSenha: String
    ) {

        mensagemErro = ""

        let emailLimpo = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Verificar campos vazios

        if emailLimpo.isEmpty ||
            senha.isEmpty ||
            confirmarSenha.isEmpty {

            mensagemErro = "Preencha todos os campos."
            return
        }

        // Verificar o formato do e-mail

        let partesEmail = emailLimpo.split(
            separator: "@",
            omittingEmptySubsequences: false
        )

        if partesEmail.count != 2 ||
            partesEmail[0].isEmpty ||
            partesEmail[1].isEmpty ||
            !partesEmail[1].contains(".") {

            mensagemErro = "Digite um e-mail válido."
            return
        }

        // Verificar o tamanho da senha

        if senha.count < 8 {

            mensagemErro = "A senha precisa ter pelo menos 8 caracteres."
            return
        }

        // Verificar confirmação da senha

        if senha != confirmarSenha {

            mensagemErro = "As senhas não são iguais."
            return
        }

        // Verificar se a conta já existe

        if contas.contains(where: { $0.email == emailLimpo }) {

            mensagemErro = "Este e-mail já está cadastrado."
            return
        }

        // Criar nova conta

        let novaConta = ContaLocal(
            email: emailLimpo
        )

        let novasContas = contas + [novaConta]

        guard let dados = try? JSONEncoder().encode(novasContas) else {

            mensagemErro = "Não foi possível criar a conta."
            return
        }

        // Salvar a senha no Keychain

        if !salvarSenha(senha, email: emailLimpo) {

            mensagemErro = "Não foi possível salvar a senha."
            return
        }

        // Salvar a conta no aparelho

        UserDefaults.standard.set(
            dados,
            forKey: contasKey
        )

        contas = novasContas

        // Entrar automaticamente após o cadastro

        iniciarSessao(conta: novaConta)
    }

    // MARK: - LOGIN

    func entrar(email: String, senha: String) {

        mensagemErro = ""

        let emailLimpo = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Verificar campos vazios

        if emailLimpo.isEmpty || senha.isEmpty {

            mensagemErro = "Preencha todos os campos."
            return
        }

        // Procurar conta cadastrada

        guard let conta = contas.first(where: {
            $0.email == emailLimpo
        }) else {

            mensagemErro = "E-mail ou senha incorretos."
            return
        }

        // Recuperar a senha salva

        guard let senhaSalva = recuperarSenha(
            email: emailLimpo
        ) else {

            mensagemErro = "Não foi possível acessar esta conta."
            return
        }

        // Verificar senha

        if senha == senhaSalva {

            iniciarSessao(conta: conta)

        } else {

            mensagemErro = "E-mail ou senha incorretos."
        }
    }

    // MARK: - INICIAR SESSÃO

    private func iniciarSessao(conta: ContaLocal) {

        mensagemErro = ""

        usuarioAtual = conta

        UserDefaults.standard.set(
            conta.email,
            forKey: sessaoKey
        )
    }

    // MARK: - SAIR DA CONTA

    func sair() {

        mensagemErro = ""

        usuarioAtual = nil

        UserDefaults.standard.removeObject(
            forKey: sessaoKey
        )
    }

    // MARK: - SALVAR SENHA NO KEYCHAIN

    private func salvarSenha(
        _ senha: String,
        email: String
    ) -> Bool {

        guard let dados = senha.data(using: .utf8) else {
            return false
        }

        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: email
        ]

        var novoItem = consulta

        novoItem[kSecValueData as String] = dados

        novoItem[kSecAttrAccessible as String] =
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let resultado = SecItemAdd(
            novoItem as CFDictionary,
            nil
        )

        if resultado == errSecSuccess {
            return true
        }

        // Atualizar uma senha antiga, se necessário

        if resultado == errSecDuplicateItem {

            let novosDados: [String: Any] = [
                kSecValueData as String: dados
            ]

            return SecItemUpdate(
                consulta as CFDictionary,
                novosDados as CFDictionary
            ) == errSecSuccess
        }

        return false
    }

    // MARK: - RECUPERAR SENHA DO KEYCHAIN

    private func recuperarSenha(email: String) -> String? {

        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: email,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var resultado: CFTypeRef?

        let status = SecItemCopyMatching(
            consulta as CFDictionary,
            &resultado
        )

        guard status == errSecSuccess,
              let dados = resultado as? Data else {

            return nil
        }

        return String(
            data: dados,
            encoding: .utf8
        )
    }
}

// MARK: - FUNDO CIRCULAR

struct FundoCircular<Conteudo: View>: View {

    let conteudo: Conteudo

    init(@ViewBuilder conteudo: () -> Conteudo) {
        self.conteudo = conteudo()
    }

    var body: some View {

        GeometryReader { tela in

            let diametro = min(
                max(tela.size.width * 1.4, 520),
                650
            )

            ZStack {

                // Fundo rosa

                Color.pink
                    .ignoresSafeArea()

                // Círculo decorativo

                Circle()
                    .fill(Color.white.opacity(0.20))
                    .frame(
                        width: diametro + 45,
                        height: diametro + 45
                    )
                    .offset(x: 12, y: -8)

                // Círculo branco principal

                Circle()
                    .fill(Color.white)
                    .frame(
                        width: diametro,
                        height: diametro
                    )
                    .shadow(
                        color: Color.pink.opacity(0.15),
                        radius: 25,
                        y: 10
                    )

                // Conteúdo centralizado

                ScrollView {

                    VStack {
                        conteudo
                    }
                    .frame(
                        maxWidth: min(
                            tela.size.width - 60,
                            330
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: tela.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .frame(
                width: tela.size.width,
                height: tela.size.height
            )
        }
    }
}

// MARK: - CONTENTVIEW

struct ContentView: View {

    @StateObject private var auth = LocalAuthStore()

    var body: some View {

        Group {

            if auth.usuarioAtual != nil {

                NavigationStack {
                    HomeView(auth: auth)
                }

            } else {

                NavigationStack {
                    LoginView(auth: auth)
                }
            }
        }
    }
}

// MARK: - TELA DE LOGIN

struct LoginView: View {

    @ObservedObject var auth: LocalAuthStore

    @State private var email = ""
    @State private var senha = ""

    var body: some View {

        FundoCircular {

            VStack(spacing: 15) {

                // Nome do aplicativo

                Text("JobRate")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.pink)

                // Subtítulo

                Text("Entre na sua conta")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)

                // Campo de e-mail

                TextField("E-mail", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .frame(height: 52)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)

                // Campo de senha

                SecureField("Senha", text: $senha)
                    .textContentType(.password)
                    .padding()
                    .frame(height: 52)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)

                // Mensagem de erro

                if !auth.mensagemErro.isEmpty {

                    Text(auth.mensagemErro)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // Botão de entrar

                Button {

                    auth.entrar(
                        email: email,
                        senha: senha
                    )

                } label: {

                    Text("Entrar")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .foregroundColor(.white)
                .background(Color.pink)
                .cornerRadius(12)
                .padding(.top, 10)

                // Botão de criar conta

                NavigationLink {

                    CadastroView(auth: auth)

                } label: {

                    Text("Criar conta")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .foregroundColor(.pink)
                .background(Color.pink.opacity(0.10))
                .cornerRadius(12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            auth.mensagemErro = ""
        }
    }
}

// MARK: - TELA DE CADASTRO

struct CadastroView: View {

    @ObservedObject var auth: LocalAuthStore

    @State private var email = ""
    @State private var senha = ""
    @State private var confirmarSenha = ""

    var body: some View {

        FundoCircular {

            VStack(spacing: 15) {

                // Título

                Text("Criar conta")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.pink)

                // Subtítulo

                Text("Cadastre-se no JobRate")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)

                // Campo de e-mail

                TextField("E-mail", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .frame(height: 52)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)

                // Campo de senha

                SecureField("Senha", text: $senha)
                    .textContentType(.newPassword)
                    .padding()
                    .frame(height: 52)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)

                // Confirmar senha

                SecureField(
                    "Confirmar senha",
                    text: $confirmarSenha
                )
                .textContentType(.newPassword)
                .padding()
                .frame(height: 52)
                .background(Color.black.opacity(0.05))
                .cornerRadius(12)

                // Mensagem de erro

                if !auth.mensagemErro.isEmpty {

                    Text(auth.mensagemErro)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // Botão cadastrar

                Button {

                    auth.cadastrar(
                        email: email,
                        senha: senha,
                        confirmarSenha: confirmarSenha
                    )

                } label: {

                    Text("Cadastrar")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .foregroundColor(.white)
                .background(Color.pink)
                .cornerRadius(12)
                .padding(.top, 10)
            }
        }
        .navigationTitle("Cadastro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(.pink)
        .onAppear {
            auth.mensagemErro = ""
        }
    }
}

// MARK: - TELA INICIAL

struct HomeView: View {

    @ObservedObject var auth: LocalAuthStore

    var body: some View {

        ZStack {

            // Fundo

            Color.pink.opacity(0.08)
                .ignoresSafeArea()

            VStack(spacing: 20) {

                // Ícone do usuário

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.pink)

                // Mensagem de boas-vindas

                Text("Bem-vindo(a) ao JobRate!")
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.center)

                // E-mail da conta

                Text(auth.usuarioAtual?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Estado da conta

                Text("Sua conta está conectada.")
                    .font(.subheadline)

                // Botão para sair

                Button {

                    auth.sair()

                } label: {

                    Text("Sair da conta")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .foregroundColor(.white)
                .background(Color.pink)
                .cornerRadius(12)
                .padding(.top, 20)
            }
            .padding(30)
        }
        .navigationTitle("JobRate")
    }
}

// MARK: - PREVIEW

#Preview {
    ContentView()
}
