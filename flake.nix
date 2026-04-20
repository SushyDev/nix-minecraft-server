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
						url = "https://meta.fabricmc.net/v2/versions/loader/26.1.2/0.19.2/1.1.1/server/jar";
						sha256 = "1gax8i1risr0irgcmbwc0jdf78yhahplsqiyhiblrq7hkydx26z9";
					};
					
					mods = {
						distant_horizons = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/uCdwusMi/versions/oIitqzZi/DistantHorizons-3.0.1-b-26.1.2-fabric-neoforge.jar";
							sha256 = "sha256-kJCkLQ32wwl66CuzNzU7R4RNT7ufRK+3V6JIP12/zMU=";
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
							url = "https://cdn.modrinth.com/data/swbUV1cr/versions/wsiZLBKu/bluemap-5.20-forge.jar";
							sha256 = "sha256-1D9XV6Y93ffwDTJ2lXZxkI7U8L+bVRuNo1Wi/JYRUyQ=";
						};
						fabric_api = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/tnmuHGZA/fabric-api-0.146.1%2B26.1.2.jar";
							sha256 = "sha256-8Jy/xmxRtw4z4GJ+38wwbXHVn4NGYp4w/mFvW9cmvKg=";
						};
						lithium = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/R7MxYvuW/lithium-fabric-0.24.2%2Bmc26.1.2.jar";
							sha256 = "sha256-IlKJ8aLw4nSbNl9lpJwD6o9FJEXkmJmVEME8s5ndTgA=";
						};
						appleskin = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/EsAfCjCV/versions/HwaLJe3v/appleskin-fabric-mc26.1-3.0.9.jar";
							sha256 = "sha256-iNCycR/oxqFpbPGfIcfgfWOm7PzPiIu5AmBWb8asTb4=";
						};
						simple_voice_chat = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/9eGKb6K1/versions/eGxtLv6D/voicechat-fabric-2.6.16%2B26.1.2.jar";
							sha256 = "sha256-IlKJ8aLw4nSbNl9lpJwD6o9FJEXkmJmVEME8s5ndTgA=";
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
