{
	description = "Minecraft server";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

	outputs = { self, nixpkgs, ... }@inputs:
		let
			supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

			mkMinecraftServerPackage = (pkgs: server: mods: 
				pkgs.stdenv.mkDerivation {
					name = "minecraft-server";
					version = "1.0.0";
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
						url = "https://meta.fabricmc.net/v2/versions/loader/26.2/0.19.3/1.1.2/server/jar";
						sha256 = "sha256-MB+DqsNrI/K8ZMxYVg7fmFM8+qMOU68AK6lQx19BALQ=";
					};
					
					mods = {
						distant_horizons = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/uCdwusMi/versions/gBf0SaV1/DistantHorizons-3.2.0-b-26.2-fabric-neoforge.jar";
							sha256 = "sha256-+3pg+gZ3XSCP9HzkuYxmjNxSdEnDfaSoBoaVeURWNJ8=";
						};
						# xaeros_world_map = pkgs.fetchurl {
						# 	url = "https://cdn.modrinth.com/data/NcUtCpym/versions/81Qc21E2/XaerosWorldMap_1.39.17_Fabric_1.21.9.jar";
						# 	sha256 = "1k0icyj3iwq130f89xb2baz2z3dzrak7dcapfzd0d7zl1l65mx3d";
						# };
						# xaeros_minimap = pkgs.fetchurl {
						# 	url = "https://cdn.modrinth.com/data/1bokaNcj/versions/hztxb2W2/Xaeros_Minimap_25.2.15_Fabric_1.21.9.jar";
						# 	sha256 = "1xqac2k5qvizs4rnnkqssk4dlgmzramxc5afgc0hbclbbmyhnl63";
						# };
						bluemap = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/swbUV1cr/versions/VTvifNPN/bluemap-5.22-fabric.jar";
							sha256 = "sha256-TDdMY8q/eEsXt2noFMTAiPFfMnvLo2QR5A2ttRhiJ6c=";
						};
						fabric_api = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/3gT0I5vt/fabric-api-0.156.0%2B26.2.jar";
							sha256 = "sha256-jeGNn2qKKlshIO+ei/+3nMm3WYnAwCLDnJ38G8Oimpk=";
						};
						lithium = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/f7vZ0VWU/lithium-fabric-0.25.3%2Bmc26.2.jar";
							sha256 = "sha256-/d6S4jjoB1+JrX9wHyo9WFSviLqaZ2VxhKRAexBKxWM=";
						};
						appleskin = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/EsAfCjCV/versions/uo5bAN1Y/appleskin-fabric-mc26.2-3.0.10.jar";
							sha256 = "sha256-6S9NKJc67Hup27+nTRY6H62rAoj7NIIkfrRDzwOqIXg=";
						};
						simple_voice_chat = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/9eGKb6K1/versions/3SOh5iiX/voicechat-fabric-2.6.21%2B26.2.jar";
							sha256 = "sha256-7V+hoRf6Jr+8hGPCf4io3/xT2id3gfJm7RESKB9/Zfc=";
						};
					};

					minecraftServer = mkMinecraftServerPackage pkgs server mods;

					dockerImage = pkgs.dockerTools.buildLayeredImage {
						name = "nix-minecraft-server";
						tag = "latest";
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
				in
				{ 
					default = minecraftServer;
					docker = dockerImage;
				}
			);
		in
		{
			packages = nixpkgs.lib.genAttrs supportedSystems mkHorkromServer;
		};
}
