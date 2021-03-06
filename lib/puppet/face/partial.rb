# Select and show a list of resources of a given type.
Puppet::Face.define(:partial, '0.0.1') do
  action :repo_build do
    summary "Retrieve a catalog for a given role, filter it for resources like packages and repos, and create a local yum repository to serve"
    arguments "<role>"

    returns <<-'EOT'
      "Applies a catalog and doesn't return anything of note"
    EOT
    option "--repo_path REPO_PATH" do
      summary "The path to place package files in"
    end

    option "--installed INSTALLED" do
      summary "Whether to also load installed packages from this node into the mirror"
    end
    when_invoked do |role, options|
      facts = Puppet::Face[:facts, :current].find('node')
      facts.values['role'] = role

      node = Puppet::Node.new('role', options={:parameters => facts.values})

      catalog = Puppet::Resource::Catalog.indirection.find('role', options = {:use_node => node})

      if options.has_key? :repo_path
        path = options[:repo_path]
      else
        path = '/usr/share/yumrepo'
      end

      if options.has_key? :installed
        installed = options[:installed]
      else
        installed = true
      end

      tcat = Puppet::Resource::Catalog.new('test', Puppet::Node::Environment.new('production'))
      tcat.make_default_resources
      anchor = tcat.create_resource('anchor', {'title' => 'start'})
      anchor = tcat.create_resource('anchor', {'title' => 'repos'})

      tcat.create_resource('file', {'title' => path, 'ensure' => 'directory', 'before' => 'Package[yum-utils]' })
      tcat.create_resource('package', {'title' => 'yum-utils', 'ensure' => 'installed', 'require' => 'Anchor[repos]' })

      catalog.resources.each do |res|
        if res.type.downcase == 'package' then
          tcat.create_resource('exec', { 'title' => "exec_#{res.title}", 'path' => '/usr/bin:/bin:/usr/sbin:/sbin', 'timeout' => 0, 'command' => "repotrack -a x86_64 -p #{path} #{res['name']}", 'require' => 'Package[yum-utils]'})
        elsif res.type.downcase == 'yumrepo'
          newres = res.to_hash
          newres[:before] = 'Anchor[repos]'
          newres.delete(:notify)
          newres.delete(:require)
          newres[:title] = res.title
          puts newres
          tcat.create_resource('yumrepo', newres)
        end
      end
      tcat.finalize
      transaction = tcat.apply()
      return
    end
  end

  action :image_build do
    summary "Retrieve a catalog, filter it for image building resources like packages and repos, and apply it"

    arguments "<host>"

    returns <<-'EOT'
      A puppet manifest containing the package and repository resources separated
      by an anchor.
    EOT

    description <<-'EOT'
    EOT

    notes <<-'NOTES'
      Work in progress as a packer provider
    NOTES

    examples <<-'EOT'
      Compile a catalog and select the resources for image building for the node compute1
      and output a simplified manifest to /root/image.pp

      $ puppet partial image_build somenode.magpie.lan --outfile=/root/image.pp
    EOT

    when_invoked do |host, options|
      catalog = Puppet::Resource::Catalog.indirection.find(host)

      tcat = Puppet::Resource::Catalog.new('test', Puppet::Node::Environment.new('production'))
      tcat.make_default_resources
      anchor = tcat.create_resource('anchor', {'title' => 'break'})

      catalog.resources.each do |res|
        if res.type.downcase == 'package' then
          tcat.create_resource('package', {'title' => res['name'], 'require' => 'Anchor[break]'})
        elsif res.type.downcase == 'yumrepo'
          tcat.create_resource('yumrepo', {'title' => res.title, 'name' => res['name'], 'baseurl' => res['baseurl'], 'before' => 'Anchor[break]' })
        end
      end
      tcat.finalize
      transaction = tcat.apply()
      return
    end
  end

  action :resource_list do
    summary "Retrieve a catalog, filter resource list and create a list."

    arguments "<hosts>"

    option "--resource <package,service,file,(...)>" do
      summary "List the resources on a specific type"
    end

    option "--tag <tag>" do
      summary "List the resources on a specific tag"
    end

    returns <<-'EOT'
      A list containing the resources.
    EOT

    description <<-'EOT'
    EOT

    notes <<-'NOTES'
    NOTES

    examples <<-'EOT'
      Compile a catalog and select the resources managed by Puppet on one node.

      $ puppet partial resource_list somenode.magpie.lan
      $ puppet partial resource_list --tag neutron::server --resource package somenode.magpie.lan
    EOT

    when_invoked do |host, options|
      catalog = Puppet::Resource::Catalog.indirection.find(host)

      tcat = Puppet::Resource::Catalog.new('test', Puppet::Node::Environment.new('production'))
      tcat.make_default_resources

      catalog.resources.each do |res|
        resource = options[:resource]
        if options.has_key? :tag
          tag = options[:tag]
          if res.type.downcase == resource and res.tags.include?(tag) then
            puts "#{res['name']}"
          end
        else
          if res.type.downcase == resource then
            puts "#{res['name']}"
          end
        end
      end
      return
    end
  end

end
