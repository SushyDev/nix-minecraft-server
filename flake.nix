{
	description = "Minecraft server";
	inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

	outputs = { self, nixpkgs, ... }@inputs:
		let
			supportedSystems = nixpkgs.lib.platforms.all;

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

							makeWrapper ${pkgs.temurin-jre-bin}/bin/java ${binPath} \
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
						url = "https://meta.fabricmc.net/v2/versions/loader/1.21.10/0.17.3/1.1.0/server/jar";
						sha256 = "0ddsiwyzkmifiprr1gaapvcrjrfvysxq72s7384sbzkacyn2sg9p";
					};
					
					mods = {
						distant_horizons = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/uCdwusMi/versions/9Y10ZuWP/DistantHorizons-2.3.6-b-1.21.10-fabric-neoforge.jar";
							sha256 = "0y35pb16c9p50qbdisnybmg83kwllds03s63yyjlid5lq38c5nwc";
						};
						xaeros_world_map = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/NcUtCpym/versions/81Qc21E2/XaerosWorldMap_1.39.17_Fabric_1.21.9.jar";
							sha256 = "1k0icyj3iwq130f89xb2baz2z3dzrak7dcapfzd0d7zl1l65mx3d";
						};
						xaeros_minimap = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/1bokaNcj/versions/hztxb2W2/Xaeros_Minimap_25.2.15_Fabric_1.21.9.jar";
							sha256 = "1xqac2k5qvizs4rnnkqssk4dlgmzramxc5afgc0hbclbbmyhnl63";
						};
						bluemap = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/swbUV1cr/versions/d38XhzPO/bluemap-5.12-fabric.jar";
							sha256 = "1kn7zbk9siw676aik0zlbwkxvp8shvlzyqn5sl1gx6xcfy5cw30h";
						};
						fabric_api = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/lxeiLRwe/fabric-api-0.136.0+1.21.10.jar";
							sha256 = "15sps2rjpqqbpd5m85cigsc72wmgckm8lvzi2za10phjsd080ch0";
						};
						lithium = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/oGKQMdyZ/lithium-fabric-0.20.0+mc1.21.10.jar";
							sha256 = "0jq0219f664qplb2lz25ai2rjfln0mi8s8f400n9hy7na0vz5bp7";
						};
						appleskin = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/EsAfCjCV/versions/8sbiz1lS/appleskin-fabric-mc1.21.9-3.0.7.jar";
							sha256 = "128bh1p1m2bavwiimb4b6gypm6yx4hxsd4l4kdhbghpl78aincbs";
						};
						simple_voice_chat = pkgs.fetchurl {
							url = "https://cdn.modrinth.com/data/9eGKb6K1/versions/BjR2lc4k/voicechat-fabric-1.21.10-2.6.6.jar";
							sha256 = "0xmkqcnh9v0sd4clx0q1m970d0vvy0vwa0mfa9kq12zc28q6jbn8";
						};
					};

					minecraftServer = mkMinecraftServerPackage pkgs server mods;
				in
				{ 
					default = minecraftServer;
				}
			);
		in
		{
			packages = nixpkgs.lib.genAttrs supportedSystems mkHorkromServer;
		};
}
