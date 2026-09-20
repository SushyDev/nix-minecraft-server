{
	description = "Minecraft server";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

	outputs = { self, nixpkgs, ... }@inputs:
		let
			supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

			modsData = builtins.fromJSON (builtins.readFile ./mods.json);
			minecraftVersion = modsData.minecraft_version;

			mkMinecraftServerPackage = (pkgs: server: mods:
				pkgs.stdenv.mkDerivation {
					name = "minecraft-server";
					version = minecraftVersion;
					src = ./.;

					nativeBuildInputs = [ pkgs.makeWrapper ];

					installPhase =
						let
							shareDirectory = "$out/share/minecraft-server";
							serverPath = "${shareDirectory}/server.jar";
							modsDirectory = "${shareDirectory}/mods";

							binDirectory = "$out/bin";
							binName = "minecraft-server";
							binPath = "${binDirectory}/${binName}";


							copyModCommand = name: file: "cp ${file} ${modsDirectory}/${name}.jar";
							copyModCommands = pkgs.lib.mapAttrsToList copyModCommand mods;
						in
						''
							mkdir -p ${binDirectory}
							mkdir -p ${shareDirectory}
							mkdir -p ${modsDirectory}

							${pkgs.lib.concatStringsSep "\n" copyModCommands}

							cp ${server} ${serverPath}

							makeWrapper ${pkgs.temurin-jre-bin-25}/bin/java ${binPath} \
								--prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.coreutils ]} \
								--add-flags "-jar ${serverPath} nogui" \
								--run "export MINECRAFT_DATA=\''${MINECRAFT_DATA:-\$(pwd)}" \
								--run "cd \"\$MINECRAFT_DATA\"" \
								--run "ln -sf ${modsDirectory} \"\$MINECRAFT_DATA/mods\"";
						'';

					meta.mainProgram = "minecraft-server";
				}
			);

			mkHorkromServer = (system:
				let
					pkgs = import nixpkgs { inherit system; };

					server = pkgs.fetchurl {
						url = modsData.fabric.server_url;
						sha256 = modsData.fabric.server_sha256;
					};

					mods = builtins.listToAttrs (map (mod: {
						name = mod.name;
						value = pkgs.fetchurl {
							url = mod.url;
							sha256 = mod.sha256;
						};
					}) modsData.mods);

					minecraftServer = mkMinecraftServerPackage pkgs server mods;

					dockerImage = pkgs.dockerTools.buildLayeredImage {
						name = "nix-minecraft-server";
						tag = minecraftVersion;
						contents = [ minecraftServer pkgs.bash pkgs.coreutils pkgs.temurin-jre-bin-25 ];
						config = {
							Env = [
								"MINECRAFT_DATA=/data"
								"PATH=${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.bash ]}"
							];
							WorkingDir = "/data";
							Volumes = { "/data" = {}; };
							Entrypoint = [ "${minecraftServer}/bin/minecraft-server" ];
						};
					};

					update = pkgs.writeShellApplication {
						name = "update-mods";
						runtimeInputs = [ pkgs.python3 pkgs.nix pkgs.curl ];
						text = ''
							cd "''${GITHUB_WORKSPACE:-$(git rev-parse --show-toplevel)}"
							exec python3 ${./scripts/update_mods.py} "$@"
						'';
					};
				in
				{
					packages = {
						default = minecraftServer;
						docker = dockerImage;
					};
					apps = {
						update = {
							type = "app";
							program = "${update}/bin/update-mods";
						};
					};
				}
			);

			perSystem = nixpkgs.lib.genAttrs supportedSystems mkHorkromServer;
		in
		{
			packages = nixpkgs.lib.mapAttrs (system: outputs: outputs.packages) perSystem;
			apps = nixpkgs.lib.mapAttrs (system: outputs: outputs.apps) perSystem;
		};
}
